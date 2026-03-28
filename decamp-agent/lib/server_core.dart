import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart' as shelf;

import 'controllers/session_controller.dart';
import 'router.dart';
import 'services/database_manager.dart';
import 'services/notification_dispatcher.dart';

final _log = Logger('ServerCore');

/// The core server services, independent of transport (mTLS, Unix socket, etc).
///
/// Created by [startServerCore]. Holds all initialized services and the Shelf
/// [handler] ready to be served over any HTTP transport.
class ServerCore {
  final DatabaseManager dbManager;
  final CrdtSettingsService settingsService;
  final SecretsService secretsService;
  final SessionController sessionController;
  final shelf.Handler handler;

  ServerCore({
    required this.dbManager,
    required this.settingsService,
    required this.secretsService,
    required this.sessionController,
    required this.handler,
  });
}

/// Initializes all server services and returns a [ServerCore].
///
/// This sets up the database, CRDT services, sync controller, and Shelf
/// request handler pipeline. It does NOT handle transport binding (mTLS,
/// Unix sockets), signal handling, .env loading, or log listener setup.
///
/// [dataPath] is the directory for databases and project data.
/// [notificationDispatcher] handles push notifications. Pass a disabled
///   instance for testing.
Future<ServerCore> startServerCore({
  required String dataPath,
  required NotificationDispatcher notificationDispatcher,
}) async {
  // Initialize DatabaseManager
  final dbManager = DatabaseManager(dataPath);
  await dbManager.init();

  // Migrate CRDT settings TOML files from legacy 'server' node ID.
  // Must run before CrdtSettingsService loads them.
  await migrateAllSettingsToml(dataPath, 'server', dbManager.nodeId);

  // Initialize CrdtSettingsService
  final settingsService = CrdtSettingsService(
    () async => Directory(dataPath),
    (projectId) async => Directory('$dataPath/projects/$projectId'),
  );
  await settingsService.init();

  // Initialize SecretsService
  final secretsService = SecretsService(
    (projectId) async => MemoryStorageImpl(),
  );

  // Initialize SessionController
  final sessionController = await SessionController.create(
    dbManager,
    settingsService,
    secretsService,
    notificationDispatcher,
  );

  // Build the request handler pipeline
  final handler = const shelf.Pipeline()
      .addMiddleware(
        shelf.logRequests(
          logger: (msg, isError) {
            if (isError) {
              _log.severe(msg);
            } else {
              _log.info(msg);
            }
          },
        ),
      )
      .addMiddleware(_corsMiddleware())
      .addHandler(createRouter(sessionController).call);

  return ServerCore(
    dbManager: dbManager,
    settingsService: settingsService,
    secretsService: secretsService,
    sessionController: sessionController,
    handler: handler,
  );
}

/// CORS middleware for cross-origin requests.
shelf.Middleware _corsMiddleware() {
  return shelf.createMiddleware(
    requestHandler: (shelf.Request request) {
      if (request.method == 'OPTIONS') {
        return shelf.Response.ok('', headers: _corsHeaders);
      }
      return null;
    },
    responseHandler: (shelf.Response response) {
      return response.change(headers: _corsHeaders);
    },
  );
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
};
