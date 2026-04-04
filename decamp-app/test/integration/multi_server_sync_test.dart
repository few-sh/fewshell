@TestOn('vm')
library;

import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:decamp/providers/providers.dart';
import 'package:decamp/providers/session_provider.dart' show SessionController;
import 'package:decamp/services/connection_mapping_storage.dart';
import 'package:decamp/services/storage/flutter_secure_storage_impl.dart';
import 'package:decamp/services/sync_service.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:fewshell_agent/server_core.dart';
import 'package:fewshell_agent/services/notification_dispatcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ---------------------------------------------------------------------------
// In-process test server (same as integration harness)
// ---------------------------------------------------------------------------

class TestServer {
  late final ServerCore core;
  late final HttpServer _server;
  late final Directory _tempDir;

  Uri get serverUrl => Uri.parse('http://localhost:${_server.port}');

  Future<void> start() async {
    sqfliteFfiInit();
    _tempDir = await Directory.systemTemp.createTemp('sync_test_');
    final notificationDispatcher = NotificationDispatcher.fromEnvironment(
      getEnv: (_) => null,
    );
    core = await startServerCore(
      dataPath: _tempDir.path,
      notificationDispatcher: notificationDispatcher,
    );
    _server = await shelf_io.serve(core.handler, 'localhost', 0);
    await _waitForHealthy();
  }

  Future<void> _waitForHealthy({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final client = HttpClient();
    final deadline = DateTime.now().add(timeout);
    try {
      while (DateTime.now().isBefore(deadline)) {
        try {
          final request = await client.getUrl(
            serverUrl.replace(path: '/health'),
          );
          final response = await request.close();
          if (response.statusCode == 200) return;
        } on SocketException catch (_) {
          // not ready yet
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      throw StateError('Server failed to become healthy within $timeout');
    } finally {
      client.close();
    }
  }

  Future<void> stop() async {
    await _server.close(force: true);
    try {
      await _tempDir.delete(recursive: true);
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// In-memory ConnectionMappingStorage
// ---------------------------------------------------------------------------

class InMemoryConnectionMappingStorage extends ConnectionMappingStorage {
  final _map = <String, Map<String, dynamic>>{};
  InMemoryConnectionMappingStorage() : super(_DummySecureStorage());

  @override
  Future<void> save(
    String projectId,
    Map<String, dynamic> connectionInfo,
  ) async => _map[projectId] = connectionInfo;

  @override
  Future<Map<String, dynamic>?> get(String projectId) async => _map[projectId];

  @override
  Future<void> delete(String projectId) async => _map.remove(projectId);

  @override
  Future<Map<String, Map<String, dynamic>>> listAll() async => _map;
}

class _DummySecureStorage implements SecureStorage {
  @override
  Future<void> write({required String key, required String value}) async {}
  @override
  Future<String?> read({required String key}) async => null;
  @override
  Future<void> delete({required String key}) async {}
  @override
  Future<void> deleteAll() async {}
  @override
  Future<Map<String, String>> readAll() async => {};
}

// ---------------------------------------------------------------------------
// Headless test harness — no widget tree required
// ---------------------------------------------------------------------------

/// A no-op session controller to avoid UI/session side effects when selecting
/// projects in headless tests.
class _NoOpSessionController extends SessionController {
  _NoOpSessionController(super.ref);
  @override
  Future<void> ensureSessionSelected(String projectId) async {}
}

class HeadlessHarness {
  static const testNodeId = 'headless-test-node';

  late final GlobalDatabase globalDb;
  late final ProjectDatabase projectDb;
  late final InMemoryConnectionMappingStorage mappingStorage;
  late final SecretsCrdt secretsCrdt;
  late final ProviderContainer container;

  late Directory _tempDir;

  Future<void> setUp() async {
    _tempDir = await Directory.systemTemp.createTemp('decamp_headless_');

    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final globalResult = await CrdtExecutorFactory.createExecutor(
      ':memory:',
      testNodeId,
    );
    globalDb = GlobalDatabase(globalResult.executor, crdt: globalResult.crdt);

    final projectResult = await CrdtExecutorFactory.createExecutor(
      ':memory:',
      testNodeId,
    );
    projectDb = ProjectDatabase(
      projectResult.executor,
      crdt: projectResult.crdt,
    );

    mappingStorage = InMemoryConnectionMappingStorage();

    const storage = FlutterSecureStorage();
    final secureStorage = FlutterSecureStorageImpl(storage: storage);
    secretsCrdt = SecretsCrdt(secureStorage);
    final keychainService = KeychainService(secretsCrdt);

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        nodeIdProvider.overrideWithValue(testNodeId),
        globalDatabaseProvider.overrideWithValue(globalDb),
        projectDatabaseProvider.overrideWith((ref) {
          final projectId = ref.watch(currentProjectIdProvider);
          if (projectId == null) return null;
          return projectDb;
        }),
        connectionMappingStorageProvider.overrideWithValue(mappingStorage),
        keychainServiceProvider.overrideWithValue(keychainService),
        secretsCrdtProvider.overrideWithValue(secretsCrdt),
        sessionControllerProvider.overrideWith(
          (ref) => _NoOpSessionController(ref),
        ),
        crdtSettingsServiceProvider.overrideWith((ref) {
          final service = CrdtSettingsService(
            () async => _tempDir,
            (projectId) async =>
                Directory('${_tempDir.path}/projects/$projectId'),
          );
          ref.onDispose(() => service.close());
          return service;
        }),
      ],
    );
  }

  /// Select a project via the real SelectedProjectNotifier (session creation
  /// is short-circuited by the no-op session controller override).
  Future<void> selectProject(String? id) async {
    await container.read(currentProjectIdProvider.notifier).select(id);
  }

  Future<void> tearDown() async {
    container.dispose();
    await globalDb.close();
    await projectDb.close();
    try {
      await _tempDir.delete(recursive: true);
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Polls [test] at [interval] until it returns true or [timeout] elapses.
Future<void> pollUntil(
  Future<bool> Function() test, {
  Duration timeout = const Duration(seconds: 15),
  Duration interval = const Duration(milliseconds: 500),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await test()) return;
    await Future<void>.delayed(interval);
  }
  throw TimeoutException('pollUntil timed out after $timeout');
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // TestWidgetsFlutterBinding overrides HttpClient to block all network
  // requests (status 400). Restore the real HttpClient so test servers
  // can communicate over localhost.
  HttpOverrides.global = null;

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

  test(
    'projects sync from server B after connecting to server A first',
    () async {
      final h = HeadlessHarness();
      await h.setUp();

      try {
        // ---- Step 1: Create a project on server A, connect and sync ----
        final serverANodeId = serverA.core.dbManager.nodeId;
        await serverA.core.dbManager.globalDatabase.projectDao
            .createProjectWithId(
              name: 'Server A Project',
              serverNodeId: serverANodeId,
            );

        final syncService = h.container.read(syncServiceProvider);
        await syncService.reconnectGlobal(
          connectionInfo: {'type': 'url', 'url': serverA.serverUrl.toString()},
        );
        await syncService.waitForGlobalSync();
        await Future<void>.delayed(const Duration(seconds: 1));

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
        await serverB.core.dbManager.globalDatabase.projectDao
            .createProjectWithId(
              name: 'Server B Project',
              serverNodeId: serverBNodeId,
            );

        // ---- Step 3: Connect to server B ----
        await syncService.reconnectGlobal(
          connectionInfo: {'type': 'url', 'url': serverB.serverUrl.toString()},
        );
        await syncService.waitForGlobalSync();
        await Future<void>.delayed(const Duration(seconds: 1));

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
      } finally {
        await h.tearDown();
      }
    },
  );

  test('secrets sync from server B after connecting to server A first', () async {
    final h = HeadlessHarness();
    await h.setUp();

    try {
      // ---- Step 1: Create project on server A, select it, and sync ----
      final serverANodeId = serverA.core.dbManager.nodeId;
      const projectAId = 'proj_secrets_test_a';
      await serverA.core.dbManager.globalDatabase.projectDao
          .createProjectWithId(
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

      // Select the project (triggers projectDatabaseProvider).
      await h.selectProject(projectAId);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Connect global + project sync to server A.
      final syncService = h.container.read(syncServiceProvider);
      await syncService.reconnectGlobal(
        connectionInfo: {'type': 'url', 'url': serverA.serverUrl.toString()},
      );
      await syncService.waitForGlobalSync();
      await syncService.waitForProjectSync();
      await Future<void>.delayed(const Duration(seconds: 1));

      // ---- Step 2: Create project on server B with a secret ----
      final serverBNodeId = serverB.core.dbManager.nodeId;
      const projectBId = 'proj_secrets_test_b';
      await serverB.core.dbManager.globalDatabase.projectDao
          .createProjectWithId(
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

      // Switch to project B.
      await h.selectProject(projectBId);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // ---- Step 3: Connect to server B ----
      await syncService.reconnectGlobal(
        connectionInfo: {'type': 'url', 'url': serverB.serverUrl.toString()},
      );
      await syncService.waitForGlobalSync();

      // Poll until the secret arrives.
      Secret? secretB;
      await pollUntil(() async {
        secretB = await h.secretsCrdt.read(
          key: 'project:$projectBId:API_KEY_B',
        );
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
    } finally {
      await h.tearDown();
    }
  });

  test(
    'reconnecting to same server still syncs projects (no regression)',
    () async {
      final h = HeadlessHarness();
      await h.setUp();

      try {
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
        await Future<void>.delayed(const Duration(seconds: 1));

        final projectsFirst = await h.globalDb.projectDao
            .getProjectsByServerNodeId(serverANodeId);
        expect(projectsFirst, isNotEmpty);

        // Disconnect and reconnect to the SAME server.
        await syncService.reconnectGlobal(
          connectionInfo: {'type': 'url', 'url': serverA.serverUrl.toString()},
        );
        await syncService.waitForGlobalSync();
        await Future<void>.delayed(const Duration(seconds: 1));

        // Project should still be there.
        final projectsSecond = await h.globalDb.projectDao
            .getProjectsByServerNodeId(serverANodeId);
        expect(
          projectsSecond,
          isNotEmpty,
          reason: 'Reconnecting to the same server should not lose synced data',
        );
        expect(
          projectsSecond.any((p) => p.name == 'Reconnect Test Project'),
          isTrue,
          reason: 'Reconnect Test Project should be in the synced projects',
        );
      } finally {
        await h.tearDown();
      }
    },
  );
}
