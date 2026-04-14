import 'dart:async';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:crdt_sync/crdt_sync.dart';
import 'package:agent_core/agent_core.dart';
import '../services/database_manager.dart';
import '../services/notification_dispatcher.dart';
import '../utils/websocket_upgrade.dart';
import 'package:fewshell_agent/version.dart';

import 'agent_session.dart';

class SessionController {
  static final _log = Logger('SessionController');

  final DatabaseManager dbManager;
  final CrdtSettingsService settingsService;
  final SecretsService secretsService;
  final NotificationDispatcher notificationDispatcher;

  /// Map of active agent sessions keyed by sessionId
  final Map<String, AgentSession> _activeSessions = {};

  /// Track which sessionIds are associated with which channels for cleanup
  final Map<MultiplexedWebSocketChannel, Set<String>> _sessionIdsByChannel = {};

  static Future<SessionController> create(
    DatabaseManager dbManager,
    CrdtSettingsService settingsService,
    SecretsService secretsService,
    NotificationDispatcher notificationDispatcher,
  ) async {
    final controller = SessionController._(
      dbManager,
      settingsService,
      secretsService,
      notificationDispatcher,
    );
    await controller._init();
    return controller;
  }

  SessionController._(
    this.dbManager,
    this.settingsService,
    this.secretsService,
    this.notificationDispatcher,
  );

  /// Initialize the controller by cleaning up session mutexes for all projects.
  ///
  ///
  /// Assumptions:
  /// - SyncController is only initialized once at server start
  /// - The dbManager has already been initialized before SyncController creation
  Future<void> _init() async {
    try {
      _log.info('Initializing SyncController: cleaning up session mutexes');

      // Get all projects from the global database
      final projects =
          await dbManager.globalDatabase.projectDao.getAllProjects();

      _log.info('Found ${projects.length} projects, preinitializing...');

      // Iterate through each project and cleanup session mutexes
      for (final project in projects) {
        try {
          final projectDb = await dbManager.getProjectDatabase(project.id);
          final cleanedCount = await projectDb.sessionMutexDao.cleanupAll();

          _log.info(
            'Cleaned up $cleanedCount session mutex(es) for project ${project.id} (${project.name})',
          );

          // Also reset any stuck streaming messages
          final resetCount =
              await projectDb.messageDao.resetAllStreamingMessages();
          _log.info(
            'Reset $resetCount streaming message(s) for project ${project.id} (${project.name})',
          );

          // Clean up all message subscriptions
          final subscriptionCleanupCount =
              await projectDb.messageSubscriberDao.cleanupAll();
          _log.info(
            'Cleaned up $subscriptionCleanupCount message subscription(s) for project ${project.id} (${project.name})',
          );
        } catch (e) {
          _log.warning(
            'Failed to cleanup mutexes for project ${project.id}: $e',
          );
        }
      }

      _log.info('SyncController initialization complete');
    } catch (e) {
      _log.severe('Error during SyncController initialization: $e');
    }
  }

  Handler get handler {
    return (Request request) {
      final path = request.url.path;

      if (path == 'global') {
        return _handleGlobalSync(request);
      } else if (path.startsWith('project/')) {
        final segments = path.split('/');
        if (segments.length >= 2) {
          final projectId = segments[1];
          if (projectId.isEmpty) {
            _log.warning(
              'Received project sync request with missing project ID',
            );
            return Response.badRequest(
              body: 'Project ID is required in the URL',
            );
          }
          return webSocketHandler(pingInterval: const Duration(seconds: 30),
              (WebSocketChannel channel, String? protocol) async {
            final projectDb = await dbManager.getProjectDatabase(projectId);
            final multiplexed = MultiplexedWebSocketChannel(channel);

            // Fork channels immediately to avoid race conditions
            final settingsChannel = multiplexed.fork('\u001E');
            final secretsChannel = multiplexed.fork('\u001D');

            // Settings Sync
            final settingsCrdt =
                await settingsService.getProjectCrdt(projectId);
            final settingsSync = CrdtSync.server(
              settingsCrdt,
              settingsChannel,
              verbose: false,
            );

            // Secrets Sync
            final secretsCrdt =
                await secretsService.getProjectSecretsCrdt(projectId);
            final secretsSync = CrdtSync.server(
              secretsCrdt,
              secretsChannel,
              verbose: false,
            );

            final keychain = KeychainService(secretsCrdt);
            _setupCustomMessageHandling(
              multiplexed,
              'Project',
              db: projectDb,
              projectId: projectId,
              keychain: keychain,
            );

            _log.info(
              'Starting CrdtSync for project $projectId',
            );
            final sync = CrdtSync.server(
              projectDb.crdt,
              multiplexed,
              verbose: false,
            );

            // Ensure sync is closed when channel is closed
            unawaited(
              multiplexed.sink.done.then((_) {
                _log.info(
                  'Channel closed for project $projectId',
                );
                sync.close();
                settingsSync.close();
                secretsSync.close();
              }),
            );
          })(request);
        }
      }

      return Response.notFound('Not found');
    };
  }

  /// Handles the global sync WebSocket connection.
  ///
  /// This uses a manual WebSocket upgrade (instead of [webSocketHandler]) so
  /// we can inject the [kNodeIdHeader] header into the HTTP 101 response.
  /// Clients read this header to discover the server's CRDT identity.
  Response _handleGlobalSync(Request request) {
    return upgradeWebSocket(
      request,
      headers: {
        kNodeIdHeader: dbManager.nodeId,
        kServerVersionHeader: packageVersion,
        kMinClientVersionHeader: minimumClientVersion,
      },
      onConnection: (WebSocketChannel channel) {
        _log.info('Starting CrdtSync for global');
        final sync = CrdtSync.server(
          dbManager.globalDatabase.crdt,
          channel,
          verbose: false,
          validateRecord: (table, record) {
            if (table == 'projects') {
              // Filter out any projects that don't belong to this server node.
              final serverNodeId = record['server_node_id'] as String?;
              return serverNodeId != null && serverNodeId == dbManager.nodeId;
            }
            return true;
          },
        );

        unawaited(
          channel.sink.done.then((_) {
            _log.info('Channel closed for global');
            sync.close();
          }),
        );
      },
    );
  }

  void _setupCustomMessageHandling(
    MultiplexedWebSocketChannel channel,
    String context, {
    ProjectDatabase? db,
    required String projectId,
    required KeychainService keychain,
  }) {
    // The subscription will be automatically cancelled when the channel is closed
    // (connection dropped) as the stream will send a done event.
    channel.onCustomMessage.listen((msg) {
      _log.fine('Server ($context): Received custom message: $msg');
      if (msg['type'] == 'PING') {
        channel.safeSendCustomMessage({
          'type': 'PONG',
          'payload': msg['payload'],
        });
      } else if (msg['type'] == 'start_chat' ||
          msg['type'] == 'abort_chat' ||
          msg['type'] == 'summarize' ||
          msg['type'] == 'terminal_keys') {
        // Extract sessionId from the message to look up or create the session
        String? sessionId = msg['sessionId'] as String?;

        if (sessionId == null || sessionId.isEmpty) {
          _log.warning('Received message without valid sessionId: $msg');
          channel.safeSendCustomMessage({
            'type': 'error',
            'message': 'Missing or invalid sessionId in message',
          });
          return;
        }

        // Capture the non-null sessionId for use in closures
        final capturedSessionId = sessionId;

        // Get or create the agent session for this sessionId
        // FIXME: This is only appropriate for start_chat message as it makes no sense to
        // spawn sessions for non-running chats and tools.
        final agentSession = _activeSessions.putIfAbsent(
          capturedSessionId,
          () {
            _log.info(
              'Creating new _AgentSession for sessionId: $capturedSessionId',
            );
            return AgentSession(
              dbManager.globalDatabase,
              db,
              projectId,
              keychain,
              notificationDispatcher: notificationDispatcher,
              onComplete: () => _cleanupSessionIfNeeded(capturedSessionId),
            );
          },
        );

        // Register this channel with the session (handles both new and reused sessions)
        agentSession.registerChannel(channel);

        // Track this sessionId for this channel (for cleanup)
        _sessionIdsByChannel
            .putIfAbsent(channel, () => {})
            .add(capturedSessionId);

        agentSession.handleMessage(msg, channel);
      }
    });

    // Clean up sessions when channel closes
    channel.sink.done.then((_) {
      _log.info('Channel closed for $context');
      // Get all sessionIds that were using this channel
      final sessionIds = _sessionIdsByChannel.remove(channel);
      if (sessionIds != null) {
        // Unregister this channel from all affected sessions and trigger cleanup
        for (final sessionId in sessionIds) {
          final session = _activeSessions[sessionId];
          if (session != null) {
            session.unregisterChannel(channel);
            // Trigger cleanup check
            unawaited(_cleanupSessionIfNeeded(sessionId));
          }
        }
      }
    }).catchError((e) {
      _log.severe('Error during channel cleanup: $e');
    });
  }

  /// Clean up a session if it's no longer needed (not locked and channel closed)
  Future<void> _cleanupSessionIfNeeded(String sessionId) async {
    // FIXME: Session might leak if it's waiting on tool approval and user disconnects
    final session = _activeSessions[sessionId];
    if (session == null) return;

    // Check if the session has any active channels
    final hasActiveChannel = session.hasActiveChannels;

    // If no active channels and the session is not currently locked, remove it
    if (!hasActiveChannel) {
      final isLocked = session.projectDb != null
          ? await session.projectDb!.sessionMutexDao.isLocked(sessionId)
          : false;

      if (!isLocked) {
        _log.info(
          'Cleaning up session $sessionId (no active channel, not locked)',
        );
        session.dispose();
        _activeSessions.remove(sessionId);
      } else {
        _log.info(
          'Session $sessionId has no active channel but is still locked, keeping for now',
        );
      }
    }
  }
}
