import 'package:agent_core/agent_core.dart';
import 'package:decamp/providers/providers.dart';
import 'package:decamp/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

/// Polls until [test] returns true, pumping the tester between attempts.
/// Throws if [timeout] elapses before success.
Future<void> pollUntil(
  WidgetTester tester,
  Future<bool> Function() test, {
  Duration timeout = const Duration(seconds: 15),
  Duration interval = const Duration(milliseconds: 500),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await test()) return;
    await tester.pump(interval);
  }
  throw TimeoutException('pollUntil timed out after $timeout');
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}

/// Integration tests for multi-server CRDT sync.
///
/// These tests verify correct project discovery and secrets sync when
/// switching between two different servers — the scenario where stale
/// HLCs from server A could prevent server B's data from syncing.
void main() {
  initIntegrationTests();

  late TestServer serverA;
  late TestServer serverB;

  setUpAll(() async {
    serverA = TestServer();
    serverB = TestServer();
    await serverA.start();
    await serverB.start();
  });

  tearDownAll(() async {
    await serverA.stop();
    await serverB.stop();
  });

  testWidgets('projects sync from server B after connecting to server A first', (
    tester,
  ) async {
    final h = IntegrationTestHarness(serverA);
    await h.setUp(tester);

    // ---- Step 1: Create a project on server A, connect and sync ----
    final serverANodeId = serverA.core.dbManager.nodeId;
    await serverA.core.dbManager.globalDatabase.projectDao.createProjectWithId(
      name: 'Server A Project',
      serverNodeId: serverANodeId,
    );

    final syncService = h.container.read(syncServiceProvider);
    await syncService.reconnectGlobal(
      connectionInfo: {'type': 'url', 'url': serverA.serverUrl.toString()},
    );
    await syncService.waitForGlobalSync();
    await tester.pump(const Duration(seconds: 1));

    // Verify server A's project was synced to the client.
    final projectsA = await h.globalDb.projectDao.getProjectsByServerNodeId(
      serverANodeId,
    );
    expect(
      projectsA,
      isNotEmpty,
      reason: 'Server A project should have synced to the client',
    );

    // ---- Step 2: Create a project on server B ----
    final serverBNodeId = serverB.core.dbManager.nodeId;
    await serverB.core.dbManager.globalDatabase.projectDao.createProjectWithId(
      name: 'Server B Project',
      serverNodeId: serverBNodeId,
    );

    // ---- Step 3: Connect to server B ----
    await syncService.reconnectGlobal(
      connectionInfo: {'type': 'url', 'url': serverB.serverUrl.toString()},
    );
    await syncService.waitForGlobalSync();
    await tester.pump(const Duration(seconds: 1));

    // ---- Step 4: Verify server B's project was synced ----
    final projectsB = await h.globalDb.projectDao.getProjectsByServerNodeId(
      serverBNodeId,
    );
    expect(
      projectsB,
      isNotEmpty,
      reason:
          'Server B project should sync to the client even after server A was connected first',
    );
    expect(projectsB.first.name, 'Server B Project');

    await h.tearDown();
  });

  testWidgets('secrets sync from server B after connecting to server A first', (
    tester,
  ) async {
    final h = IntegrationTestHarness(serverA);
    await h.setUp(tester);

    // ---- Step 1: Create project on server A, select it, and sync ----
    // Use the SAME project ID on client and server so both sides use the
    // same project database and the server's secrets CRDT matches.
    final serverANodeId = serverA.core.dbManager.nodeId;
    final projectAId = 'proj_secrets_test_a';
    await serverA.core.dbManager.globalDatabase.projectDao.createProjectWithId(
      id: projectAId,
      name: 'Secrets Test Project A',
      serverNodeId: serverANodeId,
    );

    // Store a secret on server A.
    final serverASecretsCrdt = await serverA.core.secretsService
        .getProjectSecretsCrdt(projectAId);
    await serverASecretsCrdt.put('secrets', 'project:$projectAId:API_KEY_A', {
      'value': 'secret-from-server-a',
      'isVisibleToLlm': false,
    });

    // Create client-side project with the SAME ID, pointing at server A.
    await h.globalDb.projectDao.createProjectWithId(
      id: projectAId,
      name: 'Secrets Test Project A',
      serverNodeId: serverANodeId,
    );
    await h.mappingStorage.save(projectAId, {
      'type': 'url',
      'url': serverA.serverUrl.toString(),
    });
    await h.container
        .read(currentProjectIdProvider.notifier)
        .select(projectAId);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Connect global + project sync to server A.
    final syncService = h.container.read(syncServiceProvider);
    await syncService.reconnectGlobal(
      connectionInfo: {'type': 'url', 'url': serverA.serverUrl.toString()},
    );
    await syncService.waitForGlobalSync();
    await syncService.waitForProjectSync();
    await tester.pump(const Duration(seconds: 1));

    // ---- Step 2: Create project on server B with a secret ----
    final serverBNodeId = serverB.core.dbManager.nodeId;
    final projectBId = 'proj_secrets_test_b';
    await serverB.core.dbManager.globalDatabase.projectDao.createProjectWithId(
      id: projectBId,
      name: 'Secrets Test Project B',
      serverNodeId: serverBNodeId,
    );

    final serverBSecretsCrdt = await serverB.core.secretsService
        .getProjectSecretsCrdt(projectBId);
    await serverBSecretsCrdt.put('secrets', 'project:$projectBId:API_KEY_B', {
      'value': 'secret-from-server-b',
      'isVisibleToLlm': true,
    });

    // Create a client-side project with the SAME ID, pointing at server B.
    await h.globalDb.projectDao.createProjectWithId(
      id: projectBId,
      name: 'Secrets Test Project B',
      serverNodeId: serverBNodeId,
    );
    await h.mappingStorage.save(projectBId, {
      'type': 'url',
      'url': serverB.serverUrl.toString(),
    });
    await h.container
        .read(currentProjectIdProvider.notifier)
        .select(projectBId);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // ---- Step 3: Connect to server B ----
    await syncService.reconnectGlobal(
      connectionInfo: {'type': 'url', 'url': serverB.serverUrl.toString()},
    );
    await syncService.waitForGlobalSync();

    // Poll until the secret arrives — project sync needs time to establish
    // a new connection after reconnectGlobal tears down the old one.
    Secret? secretB;
    await pollUntil(tester, () async {
      secretB = await h.secretsCrdt.read(key: 'project:$projectBId:API_KEY_B');
      return secretB != null;
    });

    // ---- Step 4: Verify server B's secret arrived ----
    expect(
      secretB,
      isNotNull,
      reason:
          'Server B secret should sync to the client even after server A was connected first',
    );
    expect(secretB!.value, 'secret-from-server-b');

    await h.tearDown();
  });

  testWidgets(
    'reconnecting to same server still syncs projects (no regression)',
    (tester) async {
      final h = IntegrationTestHarness(serverA);
      await h.setUp(tester);

      final serverANodeId = serverA.core.dbManager.nodeId;
      await serverA.core.dbManager.globalDatabase.projectDao
          .createProjectWithId(
            name: 'Reconnect Test Project',
            serverNodeId: serverANodeId,
          );

      final syncService = h.container.read(syncServiceProvider);

      // First connection.
      await syncService.reconnectGlobal(
        connectionInfo: {'type': 'url', 'url': serverA.serverUrl.toString()},
      );
      await syncService.waitForGlobalSync();
      await tester.pump(const Duration(seconds: 1));

      final projectsFirst = await h.globalDb.projectDao
          .getProjectsByServerNodeId(serverANodeId);
      expect(projectsFirst, isNotEmpty);

      // Disconnect and reconnect to the SAME server.
      await syncService.reconnectGlobal(
        connectionInfo: {'type': 'url', 'url': serverA.serverUrl.toString()},
      );
      await syncService.waitForGlobalSync();
      await tester.pump(const Duration(seconds: 1));

      // Project should still be there.
      final projectsSecond = await h.globalDb.projectDao
          .getProjectsByServerNodeId(serverANodeId);
      expect(
        projectsSecond,
        isNotEmpty,
        reason: 'Reconnecting to the same server should not lose synced data',
      );
      expect(projectsSecond.first.name, 'Reconnect Test Project');

      await h.tearDown();
    },
  );
}
