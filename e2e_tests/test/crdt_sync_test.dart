import 'dart:async';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:crdt_sync/crdt_sync.dart';
import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:e2e_tests/test_client.dart';
import 'package:e2e_tests/test_harness.dart';

/// Polls [query] until [predicate] returns true, or times out.
Future<T> pollUntil<T>(
  Future<T> Function() query,
  bool Function(T) predicate, {
  Duration timeout = const Duration(seconds: 5),
  Duration interval = const Duration(milliseconds: 100),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final result = await query();
    if (predicate(result)) return result;
    await Future.delayed(interval);
  }
  throw TimeoutException('Condition not met', timeout);
}

/// Creates a client-side [GlobalDatabase] in [dir] backed by a CRDT executor.
Future<GlobalDatabase> createClientGlobalDb(String dir) async {
  final result = await CrdtExecutorFactory.createExecutor(
    p.join(dir, 'client_global.db'),
    'client-node',
  );
  final db = GlobalDatabase(result.executor, crdt: result.crdt);
  await db.customStatement('SELECT 1;');
  return db;
}

/// Creates a client-side [ProjectDatabase] in [dir] backed by a CRDT executor.
Future<ProjectDatabase> createClientProjectDb(
  String dir,
  String projectId,
) async {
  final result = await CrdtExecutorFactory.createExecutor(
    p.join(dir, 'client_project_$projectId.db'),
    'client-node',
  );
  final db = ProjectDatabase(result.executor, crdt: result.crdt);
  await db.customStatement('SELECT 1;');
  return db;
}

void main() {
  Logger.root.level = Level.WARNING;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('${record.level.name}: ${record.loggerName}: ${record.message}');
  });

  late TestServerHarness harness;
  late TestClient client;
  late Directory clientTempDir;

  setUpAll(() async {
    harness = TestServerHarness();
    await harness.start();
    client = TestClient(harness.serverUrl);
  });

  tearDownAll(() async {
    await harness.stop();
  });

  setUp(() async {
    clientTempDir = await Directory.systemTemp.createTemp('e2e_crdt_client_');
  });

  tearDown(() async {
    try {
      await clientTempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('Global CRDT sync', () {
    test('project created on server syncs to client', () async {
      // Server creates a project
      final serverNodeId = harness.core.dbManager.nodeId;
      await harness.core.dbManager.globalDatabase.projectDao
          .createProjectWithId(
        name: 'Synced Project',
        serverNodeId: serverNodeId,
      );

      // Create client-side database
      final clientDb = await createClientGlobalDb(clientTempDir.path);
      addTearDown(() => clientDb.close());

      // Connect to global sync
      final conn = await client.connectGlobal();
      addTearDown(() => conn.close());

      // Start CrdtSync.client — sync begins automatically
      final sync = CrdtSync.client(clientDb.crdt, conn.channel);
      addTearDown(() => sync.close());

      // Poll until the project arrives (onChangesetReceived fires before merge)
      final projects = await pollUntil(
        () => clientDb.projectDao.getAllProjects(),
        (p) => p.isNotEmpty,
      );

      expect(projects, hasLength(1));
      expect(projects.first.name, equals('Synced Project'));
      expect(projects.first.serverNodeId, equals(serverNodeId));
    });
  });

  group('Project CRDT sync', () {
    test('session created on server syncs to client', () async {
      const projectId = 'crdt-test-project';

      // Server creates a session in the project database
      final serverProjectDb =
          await harness.core.dbManager.getProjectDatabase(projectId);
      final sessionId = await serverProjectDb.sessionDao.createSessionWithId(
        projectId: projectId,
        description: 'Server Session',
      );

      // Create client-side project database
      final clientDb =
          await createClientProjectDb(clientTempDir.path, projectId);
      addTearDown(() => clientDb.close());

      // Connect to project sync
      final conn = await client.connectProject(projectId);
      addTearDown(() => conn.close());
      await conn.waitForReady();

      // Start CrdtSync.client on the main multiplexed channel (project data)
      final sync = CrdtSync.client(clientDb.crdt, conn.channel);
      addTearDown(() => sync.close());

      // Poll until the session arrives
      final sessions = await pollUntil(
        () => clientDb.sessionDao.getSessionsByProject(projectId),
        (s) => s.isNotEmpty,
      );

      expect(sessions, hasLength(1));
      expect(sessions.first.id, equals(sessionId));
      expect(sessions.first.description, equals('Server Session'));
    });

    test('message created on client syncs to server', () async {
      const projectId = 'crdt-test-client-msg';

      // Ensure server has the project database ready
      final serverProjectDb =
          await harness.core.dbManager.getProjectDatabase(projectId);

      // Create client-side project database
      final clientDb =
          await createClientProjectDb(clientTempDir.path, projectId);
      addTearDown(() => clientDb.close());

      // Connect to project sync
      final conn = await client.connectProject(projectId);
      addTearDown(() => conn.close());
      await conn.waitForReady();

      // Start CrdtSync.client
      final sync = CrdtSync.client(clientDb.crdt, conn.channel);
      addTearDown(() => sync.close());

      // Wait for initial handshake to complete
      await Future.delayed(const Duration(milliseconds: 500));

      // Client creates a session and message
      final now = DateTime.now();
      final sessionId = IdGenerator.sessionId();
      await clientDb.sessionDao.insertSession(
        SessionEntityCompanion(
          id: Value(sessionId),
          projectId: const Value(projectId),
          description: const Value('Client Session'),
          timestamp: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await clientDb.messageDao.insertMessageWithId(
        sessionId: sessionId,
        userId: 'user',
        userName: 'Test User',
        content: 'Hello from client',
        messageKind: MessageKind.text,
      );

      // Poll server database until the message appears
      final messages = await pollUntil<List<MessageEntity>>(
        () => serverProjectDb.messageDao.getMessagesBySession(sessionId),
        (msgs) => msgs.isNotEmpty,
      );

      expect(messages, hasLength(1));
      expect(messages.first.content, equals('Hello from client'));
      expect(messages.first.userId, equals('user'));
    });

    test('bidirectional sync: server session + client message', () async {
      const projectId = 'crdt-test-bidi';

      // Server creates a session
      final serverProjectDb =
          await harness.core.dbManager.getProjectDatabase(projectId);
      final sessionId = await serverProjectDb.sessionDao.createSessionWithId(
        projectId: projectId,
        description: 'Bidi Session',
      );

      // Client sets up
      final clientDb =
          await createClientProjectDb(clientTempDir.path, projectId);
      addTearDown(() => clientDb.close());

      final conn = await client.connectProject(projectId);
      addTearDown(() => conn.close());
      await conn.waitForReady();

      final sync = CrdtSync.client(clientDb.crdt, conn.channel);
      addTearDown(() => sync.close());

      // Poll until session arrives on client
      final clientSessions = await pollUntil(
        () => clientDb.sessionDao.getSessionsByProject(projectId),
        (s) => s.isNotEmpty,
      );

      expect(clientSessions, hasLength(1));
      expect(clientSessions.first.description, equals('Bidi Session'));

      // Client adds a message to that session
      await clientDb.messageDao.insertMessageWithId(
        sessionId: sessionId,
        userId: 'user',
        userName: 'Test User',
        content: 'Reply from client',
        messageKind: MessageKind.text,
      );

      // Poll server until message arrives
      final serverMessages = await pollUntil(
        () => serverProjectDb.messageDao.getMessagesBySession(sessionId),
        (msgs) => msgs.isNotEmpty,
      );

      expect(serverMessages, hasLength(1));
      expect(serverMessages.first.content, equals('Reply from client'));
    });
  });
}
