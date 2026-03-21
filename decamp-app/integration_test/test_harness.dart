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

// ---------------------------------------------------------------------------
// In-process test server
// ---------------------------------------------------------------------------

class TestServer {
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
    await _waitForHealthy();
  }

  Future<void> _waitForHealthy({
    Duration timeout = const Duration(seconds: 5),
    Duration interval = const Duration(milliseconds: 50),
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
          // Server not ready yet
        }
        await Future<void>.delayed(interval);
      }
      throw StateError('Test server failed to become healthy within $timeout');
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
  ) async {
    _map[projectId] = connectionInfo;
  }

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
// Integration test harness
// ---------------------------------------------------------------------------

/// Call [initIntegrationTests] once per `main()` to configure the binding
/// and suppress Drift warnings.
void initIntegrationTests() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
}

/// Per-test harness. Owns the in-memory databases, provider overrides,
/// and the in-process test server reference.
///
/// Usage:
/// ```dart
/// final h = IntegrationTestHarness(server);
/// await h.setUp(tester);
/// // ... test body ...
/// await h.tearDown();
/// ```
class IntegrationTestHarness {
  static const testNodeId = 'integration-test-node';

  final TestServer server;

  late final GlobalDatabase globalDb;
  late final ProjectDatabase projectDb;
  late final InMemoryConnectionMappingStorage mappingStorage;
  late final WidgetTester tester;
  late final ProviderContainer container;

  late Directory _tempDir;
  late SecretsCrdt _secretsCrdt;

  IntegrationTestHarness(this.server);

  /// Initialise databases, pump the app, and wait for the initial render.
  Future<void> setUp(WidgetTester t) async {
    tester = t;

    _tempDir = await Directory.systemTemp.createTemp('decamp_integ_');

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
    _secretsCrdt = SecretsCrdt(secureStorage);
    final keychainService = KeychainService(_secretsCrdt);

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
          secretsCrdtProvider.overrideWithValue(_secretsCrdt),
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
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const DecampApp();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tearDown() async {
    await globalDb.close();
    await projectDb.close();
    try {
      await _tempDir.delete(recursive: true);
    } catch (_) {}
  }

  // -----------------------------------------------------------------------
  // Actions
  // -----------------------------------------------------------------------

  /// Creates a project in the global DB, saves a connection mapping
  /// pointing at the test server, and selects it (which auto-creates
  /// a session). Waits for the UI to settle on [ChatSession].
  Future<String> createAndSelectProject(String name) async {
    final projectId = await globalDb.projectDao.createProjectWithId(name: name);
    await mappingStorage.save(projectId, {
      'type': 'url',
      'url': server.serverUrl.toString(),
    });
    await container.read(currentProjectIdProvider.notifier).select(projectId);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    return projectId;
  }

  /// Enters [text] into the chat input and submits it.
  Future<void> sendMessage(String text) async {
    await tester.enterText(find.byType(EditableText).last, text);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  /// Triggers a global sync connection to the in-process test server.
  Future<void> connectToServer() async {
    final syncService = container.read(syncServiceProvider);
    await syncService.reconnectGlobal(
      connectionInfo: {'type': 'url', 'url': server.serverUrl.toString()},
    );
    await tester.pump(const Duration(seconds: 2));
  }

  // -----------------------------------------------------------------------
  // Accessors (thin wrappers to keep test code tidy)
  // -----------------------------------------------------------------------

  String? get currentSessionId => container.read(currentSessionIdProvider);

  Future<List<MessageEntity>> sessionMessages(String sessionId) =>
      projectDb.messageDao.getMessagesBySession(sessionId);
}
