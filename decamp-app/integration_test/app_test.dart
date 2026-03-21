import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:decamp/main.dart' show DecampApp;
import 'package:decamp/providers/providers.dart';
import 'package:decamp/services/connection_mapping_storage.dart';
import 'package:decamp/services/storage/flutter_secure_storage_impl.dart';
import 'package:decamp/services/sync_service.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:fewshell_agent/server_core.dart';
import 'package:fewshell_agent/services/notification_dispatcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// In-process test server (same as e2e_tests TestServerHarness, inlined here
/// to avoid adding a dependency on the e2e_tests package).
class _TestServer {
  late final ServerCore core;
  late final HttpServer _server;
  late final Directory _tempDir;

  Uri get serverUrl => Uri.parse('http://localhost:${_server.port}');

  Future<void> start() async {
    sqfliteFfiInit();
    _tempDir = await Directory.systemTemp.createTemp('integration_test_');
    final notificationDispatcher = NotificationDispatcher.fromEnvironment(
      getEnv: (_) => null,
    );
    core = await startServerCore(
      dataPath: _tempDir.path,
      notificationDispatcher: notificationDispatcher,
    );
    _server = await shelf_io.serve(core.handler, 'localhost', 0);
  }

  Future<void> stop() async {
    await _server.close(force: true);
    try {
      await _tempDir.delete(recursive: true);
    } catch (_) {}
  }
}

/// Simple in-memory [ConnectionMappingStorage] backed by a [Map].
class _InMemoryConnectionMappingStorage extends ConnectionMappingStorage {
  final _map = <String, Map<String, dynamic>>{};

  _InMemoryConnectionMappingStorage() : super(_DummySecureStorage());

  @override
  Future<void> save(
    String projectId,
    Map<String, dynamic> connectionInfo,
  ) async {
    _map[projectId] = connectionInfo;
  }

  @override
  Future<Map<String, dynamic>?> get(String projectId) async {
    return _map[projectId];
  }

  @override
  Future<void> delete(String projectId) async {
    _map.remove(projectId);
  }

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Suppress Drift's "multiple database" warning — we intentionally create
  // an in-memory GlobalDatabase and override the provider.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late _TestServer server;
  late GlobalDatabase globalDb;
  late Directory tempDir;

  setUpAll(() async {
    server = _TestServer();
    await server.start();
  });

  tearDownAll(() async {
    await server.stop();
  });

  testWidgets('create project, create session, send chat message', (
    tester,
  ) async {
    // --- Setup in-memory databases ---
    tempDir = await Directory.systemTemp.createTemp('decamp_integ_');

    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const testNodeId = 'integration-test-node';

    final globalResult = await CrdtExecutorFactory.createExecutor(
      ':memory:',
      testNodeId,
    );
    globalDb = GlobalDatabase(globalResult.executor, crdt: globalResult.crdt);

    // Pre-create the in-memory project database. We'll return it from
    // the projectDatabaseProvider override once a project is selected.
    final projectResult = await CrdtExecutorFactory.createExecutor(
      ':memory:',
      testNodeId,
    );
    final projectDb = ProjectDatabase(
      projectResult.executor,
      crdt: projectResult.crdt,
    );

    final mappingStorage = _InMemoryConnectionMappingStorage();

    const storage = FlutterSecureStorage();
    final secureStorage = FlutterSecureStorageImpl(storage: storage);
    final secretsCrdt = SecretsCrdt(secureStorage);
    final keychainService = KeychainService(secretsCrdt);

    // --- Pump the app with provider overrides ---
    late ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
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
          crdtSettingsServiceProvider.overrideWith((ref) {
            final service = CrdtSettingsService(
              () async => tempDir,
              (projectId) async =>
                  Directory('${tempDir.path}/projects/$projectId'),
            );
            ref.onDispose(() => service.close());
            return service;
          }),
        ],
        child: Builder(
          builder: (context) {
            // Capture the container for programmatic provider access.
            container = ProviderScope.containerOf(context);
            return const DecampApp();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // ---- Step 1: Verify we start on the ProjectsPage (empty) ----
    // The SelectableListView shows "No projects" when the list is empty,
    // and a FAB labelled "New Project".
    expect(find.text('No projects'), findsOneWidget);

    // ---- Step 2: Create a project programmatically ----
    final projectId = await globalDb.projectDao.createProjectWithId(
      name: 'Test Project',
    );
    // Save connection mapping so SyncService can find the test server.
    await mappingStorage.save(projectId, {
      'type': 'url',
      'url': server.serverUrl.toString(),
    });
    // Select the project — this triggers session auto-creation.
    await container.read(currentProjectIdProvider.notifier).select(projectId);
    // Allow the database stream to propagate the new project and rebuild.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // ---- Step 3: Verify ChatSession is displayed ----
    // _HomeSelector switches to ChatSession when currentProjectProvider != null.
    // Verify the "No projects" text is gone (we're no longer on ProjectsPage).
    expect(find.text('No projects'), findsNothing);

    // A session should have been auto-created. The ChatInput should be present.
    // ShadInput uses EditableText internally (not TextField).
    expect(find.byType(EditableText), findsWidgets);

    // ---- Step 4: Send a chat message ----
    const testMessage = 'Hello from integration test!';
    await tester.enterText(find.byType(EditableText).last, testMessage);
    await tester.pumpAndSettle();

    // ShadInput uses CallbackShortcuts with Enter key to send — simulate that.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // ---- Step 5: Verify message was persisted ----
    final sessionId = container.read(currentSessionIdProvider);
    expect(sessionId, isNotNull);

    final messages = await projectDb.messageDao.getMessagesBySession(
      sessionId!,
    );

    // The user message should be persisted.
    expect(messages, isNotEmpty);
    expect(
      messages.any((m) => m.content.contains(testMessage)),
      isTrue,
      reason: 'User message should be persisted in the database',
    );

    // ---- Step 6: Verify sync connection to in-process server ----
    final syncService = container.read(syncServiceProvider);
    await syncService.reconnectGlobal(
      connectionInfo: {'type': 'url', 'url': server.serverUrl.toString()},
    );
    // Give sync a moment to connect.
    await tester.pump(const Duration(seconds: 2));

    // If we got here without exceptions, the global sync handshake worked.

    // ---- Cleanup ----
    await globalDb.close();
    await projectDb.close();
    await tempDir.delete(recursive: true);
  });
}
