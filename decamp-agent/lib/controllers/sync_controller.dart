import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:crdt_sync/crdt_sync.dart';
import 'package:agent_core/agent_core.dart';
import 'package:llm_dart/llm_dart.dart';
import '../services/database_manager.dart';
import '../services/local_shell_backend.dart';
import '../services/notification_dispatcher.dart';
import '../utils/websocket_upgrade.dart';
import 'package:fewshell_agent/version.dart';

class SyncController {
  static final _log = Logger('SyncController');

  final DatabaseManager dbManager;
  final CrdtSettingsService settingsService;
  final SecretsService secretsService;
  final NotificationDispatcher notificationDispatcher;

  /// Map of active agent sessions keyed by sessionId
  final Map<String, _AgentSession> _activeSessions = {};

  /// Track which sessionIds are associated with which channels for cleanup
  final Map<MultiplexedWebSocketChannel, Set<String>> _sessionIdsByChannel = {};

  static Future<SyncController> create(
    DatabaseManager dbManager,
    CrdtSettingsService settingsService,
    SecretsService secretsService,
    NotificationDispatcher notificationDispatcher,
  ) async {
    final controller = SyncController._(
      dbManager,
      settingsService,
      secretsService,
      notificationDispatcher,
    );
    await controller._init();
    return controller;
  }

  SyncController._(
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
    String? projectId,
    KeychainService? keychain,
  }) {
    // The subscription will be automatically cancelled when the channel is closed
    // (connection dropped) as the stream will send a done event.
    channel.onCustomMessage.listen((msg) {
      _log.info('Server ($context): Received custom message: $msg');
      if (msg['type'] == 'PING') {
        channel.safeSendCustomMessage({
          'type': 'PONG',
          'payload': msg['payload'],
        });
      } else if (msg['type'] == 'start_chat' ||
          msg['type'] == 'approval_response' ||
          msg['type'] == 'abort_chat' ||
          msg['type'] == 'summarize') {
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
                'Creating new _AgentSession for sessionId: $capturedSessionId');
            return _AgentSession(
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
            'Cleaning up session $sessionId (no active channel, not locked)');
        _activeSessions.remove(sessionId);
      } else {
        _log.info(
          'Session $sessionId has no active channel but is still locked, keeping for now',
        );
      }
    }
  }
}

class _AgentSession {
  static final _log = Logger('AgentSession');

  /// Set of active channels for this session (supports reconnections)
  final Set<MultiplexedWebSocketChannel> _channels = {};

  final GlobalDatabase globalDb;
  final ProjectDatabase? projectDb;
  final String? projectId;
  final ShellService _shellService;
  final NotificationDispatcher _notificationDispatcher;
  final void Function() onComplete;
  Completer<List<PendingToolCall>?>? _approvalCompleter;
  List<PendingToolCall>? _currentPendingCalls;
  CancelToken? _currentCancelToken;
  StreamController<ProcessSignal>? _currentAbortController;

  Future<void> _lastDbWrite = Future.value();

  _AgentSession(
    this.globalDb,
    this.projectDb,
    this.projectId,
    KeychainService? keychain, {
    required NotificationDispatcher notificationDispatcher,
    required this.onComplete,
  })  : _notificationDispatcher = notificationDispatcher,
        _shellService = ShellService(
          null,
          keychain,
          projectId,
          backend: LocalShellBackend(),
        );

  /// Register a new channel with this session (handles reconnections)
  void registerChannel(MultiplexedWebSocketChannel channel) {
    _channels.add(channel);
    _log.info(
        'Registered channel with session. Total channels: ${_channels.length}');
  }

  /// Unregister a channel from this session
  /// Returns true if the channel was registered with this session
  bool unregisterChannel(MultiplexedWebSocketChannel channel) {
    final wasRegistered = _channels.remove(channel);
    if (wasRegistered) {
      _log.info(
          'Unregistered channel from session. Remaining channels: ${_channels.length}');
    }
    return wasRegistered;
  }

  /// Check if this session has any active channels
  bool get hasActiveChannels => _channels.isNotEmpty;

  void handleMessage(
      Map<String, dynamic> msg, MultiplexedWebSocketChannel channel) {
    if (msg['type'] == 'start_chat') {
      // Give CRDT sync a moment to catch up with secrets
      Future.delayed(const Duration(milliseconds: 500), () {
        _startChat(msg, channel);
      });
    } else if (msg['type'] == 'summarize') {
      // Give CRDT sync a moment to catch up
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleSummarize(msg, channel);
      });
    } else if (msg['type'] == 'approval_response') {
      _handleApproval(msg);
    } else if (msg['type'] == 'abort_chat') {
      _handleAbort(msg);
    }
  }

  void _handleAbort(Map<String, dynamic> data) {
    _log.info('🛑 Received abort request');
    _currentCancelToken?.cancel('Aborted by user');
    _currentAbortController?.add(ProcessSignal.sigterm);
  }

  Future<ChatCapability> _createProviderFromConfig(
    Map<String, dynamic> config,
  ) async {
    final apiKey = config['apiKey'] as String;
    final providerTypeStr = config['provider'] as String;
    final model = config['model'] as String;
    final baseUrl = config['baseUrl'] as String?;
    final temperature = config['temperature'] as double?;
    final maxTokens = config['maxTokens'] as int?;
    final systemInstruction = config['systemInstruction'] as String?;

    final apiType = LlmApiType.values.firstWhere(
      (e) => e.name == providerTypeStr,
      orElse: () => throw Exception('Unknown provider type: $providerTypeStr'),
    );

    final settings = LlmApiSettings(
      identifier: model,
      apiType: apiType,
      baseUrl: baseUrl ?? apiType.defaultBaseUrl,
      temperature: temperature,
      maxTokens: maxTokens,
    );

    return LlmService.createProvider(
      settings,
      apiKey,
      systemInstruction: systemInstruction,
    );
  }

  Future<void> _handleSummarize(
    Map<String, dynamic> data,
    MultiplexedWebSocketChannel channel,
  ) async {
    _log.info('📝 Received summarize request');

    final sessionId = data['sessionId'] as String?;
    final hideMessages = data['hideMessages'] as bool? ?? true;

    if (sessionId == null || projectDb == null) {
      channel.safeSendCustomMessage({
        'type': 'summarize_error',
        'message': 'Session ID and Database required',
      });
      return;
    }

    var lockAckquired = false;

    try {
      final config = data['config'] as Map<String, dynamic>;
      final provider = await _createProviderFromConfig(config);

      _currentCancelToken = CancelToken();

      final summarizer = ConversationSummarizer(
        messageDao: projectDb!.messageDao,
        llmStream: (conversation, {cancelToken}) =>
            provider.chatStream(conversation, cancelToken: cancelToken),
      );

      lockAckquired = await _lockSession(sessionId);

      if (!lockAckquired) {
        _log.warning('Chat already in progress for session $sessionId');
        channel.safeSendCustomMessage({
          'type': 'summarize_error',
          'message':
              'Session is currently busy with another operation. Please try again in a few...',
        });
        return;
      }

      final performed = await summarizer.forceSummarize(
        sessionId,
        hideMessages: hideMessages,
        cancelToken: _currentCancelToken,
      );

      channel.safeSendCustomMessage({
        'type': 'summarize_complete',
        'performed': performed,
      });
    } catch (e) {
      _log.warning('Summarization failed: $e');
      channel.safeSendCustomMessage({
        'type': 'summarize_error',
        'message': e.toString(),
      });
    } finally {
      _currentCancelToken = null;
      if (lockAckquired) {
        await _unlockSession(sessionId).catchError((e, st) {
          _log.severe(
            'Error releasing session lock for session $sessionId',
            e,
            st,
          );
        });
      }
    }
  }

  void _handleApproval(Map<String, dynamic> data) {
    _log.info('✅ Received approval response');

    if (_approvalCompleter != null && !_approvalCompleter!.isCompleted) {
      if (data['approvedCalls'] != null) {
        final approvedCalls =
            (data['approvedCalls'] as List).cast<Map<String, dynamic>>();
        final pending = _currentPendingCalls ?? [];
        final pendingById = {for (var p in pending) p.id: p};

        final approved = approvedCalls
            .map((callData) {
              final id = callData['id'] as String;
              final original = pendingById[id];
              if (original == null) {
                _log.warning(
                  'Could not find original pending call for id: $id',
                );
                return null;
              }
              final arguments = callData['arguments'] as Map<String, dynamic>;

              return PendingToolCall(
                id: id,
                name: original.name,
                arguments: arguments,
                originalToolCall: original.originalToolCall,
              );
            })
            .whereType<PendingToolCall>()
            .toList();

        _approvalCompleter!.complete(approved);
      } else {
        // Cancelled
        _approvalCompleter!.complete(null);
      }
    }
  }

  Future<bool> _lockSession(String sessionId) async {
    if (projectDb != null) {
      final acquired = await projectDb!.sessionMutexDao.acquireLock(sessionId);
      if (!acquired) {
        return false;
      }
    }
    return true;
  }

  Future<void> _unlockSession(String sessionId) async {
    if (projectDb != null) {
      await projectDb!.sessionMutexDao.unlock(sessionId);
    }
  }

  Future<void> _startChat(
      Map<String, dynamic> data, MultiplexedWebSocketChannel channel) async {
    _log.info('🚀 Starting agent loop');
    String? sessionId;

    try {
      sessionId = data['sessionId'] as String?;
    } catch (e) {
      _log.warning('Invalid session ID format', e);

      channel.safeSendCustomMessage({
        'type': 'error',
        'message': 'Invalid session ID format: $e',
      });
      return;
    }

    String projectName = '';
    if (projectId != null && projectDb != null) {
      final project = await globalDb.projectDao.getProject(projectId!);
      if (project != null) {
        projectName = project.name;
      }
    }

    if (sessionId != null) {
      final locked = await _lockSession(sessionId);
      if (!locked) {
        _log.warning('Chat already in progress for session $sessionId');
        channel.safeSendCustomMessage({
          'type': 'error',
          'message': 'Chat already in progress for session $sessionId',
        });
        return;
      }
    }

    try {
      if (sessionId == null || projectDb == null) {
        throw Exception(
          'Session ID and Database required',
        );
      }
      final currentSessionId = sessionId;

      MessageEntity streamingMessage = MessageEntity(
        id: projectDb!.messageDao.generateMessageId(),
        sessionId: sessionId,
        userId: 'ai',
        userName: 'System',
        content: '',
        timestamp: DateTime.now(),
        createdAt: DateTime.now(),
        messageKind: MessageKind.text,
        isVisibleToLlm: true,
        isStreaming: true,
      );

      try {
        final config = data['config'] as Map<String, dynamic>;
        final triggerMessageJson =
            data['triggerMessage'] as Map<String, dynamic>?;

        // If we have a trigger message, upsert it immediately to ensure we have the latest context
        if (triggerMessageJson != null) {
          _log.info(
            '📥 Received trigger message, upserting...',
          );
          final triggerMessage = MessageEntity.fromJson(triggerMessageJson);
          await projectDb!.messageDao
              .insertMessage(triggerMessage.toCompanion(true));
          _log.info(
            '✅ Trigger message ${triggerMessage.id} upserted!',
          );
        }

        final provider = await _createProviderFromConfig(config);
        final model = config['model'] as String;

        _currentCancelToken = CancelToken();
        // ignore: close_sinks
        final abortController = StreamController<ProcessSignal>.broadcast();
        _currentAbortController = abortController;

        // Run summarization before the agent loop if needed
        final summarizer = ConversationSummarizer(
          messageDao: projectDb!.messageDao,
          llmStream: (conversation, {cancelToken}) =>
              provider.chatStream(conversation, cancelToken: cancelToken),
        );
        try {
          await summarizer.summarizeIfNeeded(
            currentSessionId,
            cancelToken: _currentCancelToken,
          );
        } catch (e) {
          _log.warning('Conversation summarization failed: $e');
          // Non-fatal: continue with the full conversation
        }

        await runAgentLoop(
          getConversation: () async {
            return await _loadConversation(currentSessionId);
          },
          llmStream: (conv, tools, {cancelToken}) {
            return provider.chatStream(
              conv,
              tools: tools,
              cancelToken: cancelToken,
            );
          },
          tools: shellTools,
          cancelToken: _currentCancelToken,
          requestApproval: (pendingCalls) {
            _currentPendingCalls = pendingCalls;

            channel.safeSendCustomMessage({
              'type': 'request_approval',
              'tools': pendingCalls
                  .map(
                    (c) =>
                        {'id': c.id, 'name': c.name, 'arguments': c.arguments},
                  )
                  .toList(),
            });

            final completer = Completer<List<PendingToolCall>?>();
            _approvalCompleter = completer;
            return completer.future;
          },
          executeToolCall: (toolCalls) async {
            final results = <String>[];
            final completedToolResults = <ToolCall>[];

            streamingMessage = streamingMessage.copyWith(
              messageKind: MessageKind.toolResult,
              isStreaming: true,
              toolCallsJson: Value(toolCalls),
            );

            for (final toolCall in toolCalls) {
              final argumentsJson = toolCall.function.arguments;
              final params = argumentsJson.isNotEmpty
                  ? Map<String, dynamic>.from(jsonDecode(argumentsJson))
                  : <String, dynamic>{};

              String result;
              if (toolCall.function.name == kExecuteShellCommand) {
                final command = params['command'] as String;
                final sudoRequired = params['sudo_required'] as bool? ?? false;
                final secrets = params['secrets'] != null
                    ? List<String>.from(params['secrets'] as List)
                    : null;
                _log.info(
                  'Executing shell command. Abort controller: $abortController',
                );

                final terminalBuffer = TerminalBuffer();
                void onOutput(String data) {
                  terminalBuffer.write(data);
                  final streamingResultJson = jsonEncode({
                    'stdout': terminalBuffer.toString(),
                    'stderr': '',
                    'exitCode': 0,
                    'isStreaming': true,
                  });
                  streamingMessage = streamingMessage.copyWith(
                    toolResultsJson: Value([
                      ...completedToolResults,
                      ToolCall(
                        id: toolCall.id,
                        callType: toolCall.callType,
                        function: FunctionCall(
                          name: toolCall.function.name,
                          arguments: streamingResultJson,
                        ),
                      ),
                    ]),
                  );
                  _asyncDbWrite(() async {
                    await projectDb!.messageDao.insertMessage(
                      streamingMessage.toCompanion(true),
                    );
                  });
                }

                final Map<String, dynamic> shellResult;
                if (sudoRequired) {
                  shellResult = await _shellService.executeWithSudo(
                    command: command,
                    secrets: secrets,
                    abortSignal: abortController.stream,
                    onStdout: onOutput,
                    onStderr: onOutput,
                  );
                } else {
                  shellResult = await _shellService.executeCommand(
                    command,
                    secrets: secrets,
                    abortSignal: abortController.stream,
                    onStdout: onOutput,
                    onStderr: onOutput,
                  );
                }
                await _lastDbWrite.catchError((e) {
                  _log.warning(
                    'Error writing streaming message: $e',
                  );
                });
                await projectDb!.sessionDao.touchSession(currentSessionId);
                shellResult['stdout'] = terminalBuffer.toString();
                result = jsonEncode(shellResult);
              } else if (toolCall.function.name == kFetch) {
                final fetchResult = await FetchTool.execute(params);
                await projectDb!.sessionDao.touchSession(currentSessionId);
                result = jsonEncode(fetchResult['data']);
              } else {
                result = jsonEncode({'error': 'Unknown tool'});
              }
              results.add(result);
              completedToolResults.add(
                ToolCall(
                  id: toolCall.id,
                  callType: toolCall.callType,
                  function: FunctionCall(
                    name: toolCall.function.name,
                    arguments: result,
                  ),
                ),
              );
            }

            await projectDb!.messageDao
                .insertMessage(streamingMessage.toCompanion(true));

            return results;
          },
          onTextDelta: (delta) async {
            streamingMessage = streamingMessage.copyWith(
              content: '${streamingMessage.content}$delta',
              messageKind: MessageKind.text,
              userId: 'ai',
              userName: model,
              isStreaming: true,
            );
            await projectDb!.messageDao
                .insertMessage(streamingMessage.toCompanion(true));
          },
          onAssistantMessage: (message, {String? messageId}) async {
            // Wait for any pending streaming writes to finish
            await _lastDbWrite;

            // db and sessionId are guaranteed to be non-null here due to checks at start of method
            // Determine if this is a tool use message or a text message
            final messageType = message.messageType;
            if (messageType is ToolUseMessage) {
              streamingMessage = message.toMessageEntity(
                sessionId: currentSessionId,
                id: streamingMessage.id,
                userName: model,
              );
              await projectDb!.messageDao
                  .insertMessage(streamingMessage.toCompanion(true));
            } else {
              // Save text message
              streamingMessage = message.toMessageEntity(
                sessionId: currentSessionId,
                id: streamingMessage.id,
                userName: model,
              );
              await projectDb!.messageDao
                  .insertMessage(streamingMessage.toCompanion(true));
            }
            await projectDb!.sessionDao.touchSession(currentSessionId);
          },
          onToolResultMessage: (
            message, {
            String? messageId,
            ChatMessage? toolCallMessage,
          }) async {
            final String id = streamingMessage.id;

            final messageEntity = message.toMessageEntity(
              sessionId: sessionId!,
            );
            streamingMessage = streamingMessage.copyWith(
              messageKind: MessageKind.toolResult,
              toolResultsJson: Value(messageEntity.toolResultsJson),
              isStreaming: false,
            );

            await projectDb!.messageDao
                .insertMessage(streamingMessage.toCompanion(true));

            // Generate new ID for next message (only used if local or if server didn't provide one)
            streamingMessage = streamingMessage.copyWith(
              id: projectDb!.messageDao.generateMessageId(),
            );

            await projectDb!.sessionDao.touchSession(currentSessionId);

            // Send push notification to subscribers
            if (projectId != null) {
              unawaited(
                _notificationDispatcher.sendNotification(
                  projectDb: projectDb!,
                  projectId: projectId!,
                  sessionId: currentSessionId,
                  messageId: id,
                  title: 'Tool Execution Complete',
                  body: 'A tool has finished executing in $projectName',
                  data: {
                    'project_id': projectId!,
                    'session_id': currentSessionId,
                    'message_id': id,
                  },
                ).catchError((e, st) {
                  _log.severe(
                    'Error sending push notification for message $id: $e',
                    st,
                  );
                }),
              );
            }
          },
        );

        channel.safeSendCustomMessage({'type': 'complete'});
      } catch (e, st) {
        if (e is CancelledError) {
          _log.info('Agent loop cancelled by user');
          channel.safeSendCustomMessage({'type': 'cancelled'});
        } else {
          _log.severe('Error running agent loop: $e, $st');

          final messageId = projectDb!.messageDao.generateMessageId();

          // Try to insert error message if we have session ID and DB
          if (projectDb != null) {
            try {
              final config = data['config'] as Map<String, dynamic>?;
              final model = config?['model'] as String? ?? 'Ops Agent';

              await projectDb!.messageDao.insertMessageWithId(
                id: messageId,
                sessionId: sessionId,
                userId: 'ai',
                userName: model,
                content: 'Sorry, I encountered an error: $e',
                messageKind: MessageKind.notification,
                isVisibleToLlm: false,
              );
              await projectDb!.sessionDao.touchSession(sessionId);
            } catch (innerE) {
              _log.severe('Failed to insert error message: $innerE');
            }
          }

          channel.safeSendCustomMessage({
            'type': 'error',
            'message_id': messageId,
            'message': e.toString(),
          });
        }
      } finally {
        _currentCancelToken = null;
        await _currentAbortController?.close();
        _currentAbortController = null;

        // Ensure any pending DB writes are finished before unlocking
        try {
          await _lastDbWrite;
        } catch (e) {
          _log.warning('Error waiting for last DB write: $e');
        }

        if (projectDb != null) {
          // Clean up any streaming message placeholder
          try {
            final config = data['config'] as Map<String, dynamic>?;
            final model = config?['model'] as String? ?? 'Ops Agent';

            streamingMessage = streamingMessage.copyWith(
              userName: model,
              isStreaming: false,
            );
            await projectDb!.messageDao.updateMessage(
              streamingMessage.toCompanion(true),
            );
          } catch (e) {
            _log.warning(
              'Error cleaning up streaming message placeholder: $e',
            );
          }
        }
        _lastDbWrite = Future.value(); // Reset chain

        await _unlockSession(sessionId);
        // Trigger cleanup check after unlocking
        onComplete();
      }
    } catch (e) {
      _log.severe('Error starting chat', e);
      channel.safeSendCustomMessage({
        'type': 'error',
        'message': e.toString(),
      });

      if (sessionId != null) {
        await _unlockSession(sessionId).catchError((e) {
          _log.severe('Error unlocking session $sessionId: $e');
        });
        // Trigger cleanup check after unlocking
        onComplete();
      }
    }
  }

  Future<List<ChatMessage>> _loadConversation(String sessionId) async {
    // Always load conversation from database (single source of truth)
    // Filter out streaming placeholders to prevent confusing the LLM with empty assistant messages
    // Also filter out messages not visible to LLM
    final dbMessages =
        await projectDb!.messageDao.getMessagesBySession(sessionId);
    final conversation = dbMessages
        .where((m) =>
            !m.isStreaming &&
            m.isVisibleToLlm &&
            m.messageKind != MessageKind.notification)
        .expand((m) {
      final chatMessages = m.toChatMessage();
      // Prepend the summary prefix for conversation summary messages
      // so the LLM understands it's a handoff from a prior model.
      // The prefix is NOT stored in the DB to avoid nesting on re-summarization.
      if (m.messageKind == MessageKind.conversationSummary) {
        return chatMessages.map(
          (cm) => cm.role == ChatRole.user
              ? ChatMessage.user(
                  '$conversationSummaryPrefix${cm.content}',
                )
              : cm,
        );
      }
      return chatMessages;
    }).toList();

    // Add cache control to the last text message for Anthropic prompt caching
    // Search backwards to find the last TextMessage, as conversation may end with tool calls
    // Use cache control marker pattern: Empty text block with cache_control
    if (conversation.isNotEmpty) {
      for (int i = conversation.length - 1; i >= 0; i--) {
        if (conversation[i].messageType is TextMessage) {
          // HACK: This is not the cleanest way to do this, as it assumes anthropic, but we need to, and it works.
          // other providers simply ignore this extension on the dart_llm library side. -Ivgeni
          conversation[i] = conversation[i].withExtension(
            'anthropic',
            {
              'contentBlocks': [
                {
                  'type': 'text',
                  'text': '',
                  'cache_control': {'type': 'ephemeral', 'ttl': '5m'},
                },
              ],
            },
          );
          break; // Only cache the last text message
        }
      }
    }
    return conversation;
  }

  void _asyncDbWrite(Future<void> Function() write) {
    _lastDbWrite = _lastDbWrite.then((_) => write()).catchError((e) {
      _log.warning('Error writing streaming message: $e');
    });
  }
}
