import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:crdt_sync/crdt_sync.dart';
import 'package:agent_core/agent_core.dart';
import 'package:llm_dart/llm_dart.dart';
import 'package:drift/drift.dart';
import '../services/database_manager.dart';

class SyncController {
  static final _log = Logger('SyncController');

  final DatabaseManager dbManager;
  final CrdtSettingsService settingsService;
  final SecretsService secretsService;
  final Set<String> _activeSessions = {};

  SyncController(this.dbManager, this.settingsService, this.secretsService);

  Handler get handler {
    return (Request request) {
      final path = request.url.path;

      if (path == 'global') {
        return webSocketHandler((WebSocketChannel channel, String? protocol) {
          _log.info('Starting CrdtSync for global');
          final sync = CrdtSync.server(
            dbManager.globalDatabase.crdt,
            channel,
            verbose: true,
          );

          unawaited(
            channel.sink.done.then((_) {
              _log.info(
                'Channel closed for global',
              );
              sync.close();
            }),
          );
        })(request);
      } else if (path.startsWith('project/')) {
        final segments = path.split('/');
        if (segments.length >= 2) {
          final projectId = segments[1];
          return webSocketHandler(
              (WebSocketChannel channel, String? protocol) async {
            final db = await dbManager.getProjectDatabase(projectId);
            final multiplexed = MultiplexedWebSocketChannel(channel);
            _setupCustomMessageHandling(multiplexed, 'Project', db);

            // Fork channels immediately to avoid race conditions
            final settingsChannel = multiplexed.fork('\u001E');
            final secretsChannel = multiplexed.fork('\u001D');

            // Settings Sync
            final settingsCrdt =
                await settingsService.getProjectCrdt(projectId);
            final settingsSync = CrdtSync.server(
              settingsCrdt,
              settingsChannel,
              verbose: true,
            );

            // Secrets Sync
            final secretsCrdt =
                await secretsService.getProjectSecretsCrdt(projectId);
            final secretsSync = CrdtSync.server(
              secretsCrdt,
              secretsChannel,
              verbose: true,
            );

            _log.info(
              'Starting CrdtSync for project $projectId',
            );
            final sync = CrdtSync.server(
              db.crdt,
              multiplexed,
              verbose: true,
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

  void _setupCustomMessageHandling(
    MultiplexedWebSocketChannel channel,
    String context, [
    ProjectDatabase? db,
  ]) {
    final agentSession = _AgentSession(channel, db, _activeSessions);

    // The subscription will be automatically cancelled when the channel is closed
    // (connection dropped) as the stream will send a done event.
    channel.onCustomMessage.listen((msg) {
      _log.info('Server ($context): Received custom message: $msg');
      if (msg['type'] == 'PING') {
        channel.sendCustomMessage({
          'type': 'PONG',
          'payload': msg['payload'],
        });
      } else if (msg['type'] == 'start_chat' ||
          msg['type'] == 'approval_response' ||
          msg['type'] == 'abort_chat') {
        agentSession.handleMessage(msg);
      }
    });
  }
}

class _AgentSession {
  static final _log = Logger('AgentSession');

  final MultiplexedWebSocketChannel channel;
  final ProjectDatabase? db;
  final Set<String> _activeSessions;
  final ShellService _shellService = ShellService.local(null, null);
  Completer<List<PendingToolCall>?>? _approvalCompleter;
  List<PendingToolCall>? _currentPendingCalls;
  CancelToken? _currentCancelToken;

  // Streaming state
  String? _streamingMessageId;
  final StringBuffer _streamingContent = StringBuffer();
  DateTime? _streamingCreatedAt;
  Future<void> _lastDbWrite = Future.value();

  _AgentSession(this.channel, this.db, this._activeSessions);

  void handleMessage(Map<String, dynamic> msg) {
    if (msg['type'] == 'start_chat') {
      _startChat(msg);
    } else if (msg['type'] == 'approval_response') {
      _handleApproval(msg);
    } else if (msg['type'] == 'abort_chat') {
      _handleAbort(msg);
    }
  }

  void _handleAbort(Map<String, dynamic> data) {
    _log.info('🛑 Received abort request');
    _currentCancelToken?.cancel('Aborted by user');
  }

  void _handleApproval(Map<String, dynamic> data) {
    _log.info('✅ Received approval response');
    final approvedIds = (data['approvedIds'] as List?)?.cast<String>();

    if (_approvalCompleter != null && !_approvalCompleter!.isCompleted) {
      if (approvedIds == null) {
        _approvalCompleter!.complete(null);
      } else {
        // Filter pending calls
        final pending = _currentPendingCalls ?? [];
        final approved =
            pending.where((c) => approvedIds.contains(c.id)).toList();
        _approvalCompleter!.complete(approved);
      }
    }
  }

  Future<bool> _lockSession(String sessionId) async {
    if (_activeSessions.contains(sessionId)) {
      return false;
    }

    if (db != null) {
      final acquired = await db!.sessionMutexDao.acquireLock(sessionId);
      if (!acquired) {
        return false;
      }
    }

    _activeSessions.add(sessionId);
    return true;
  }

  Future<void> _unlockSession(String sessionId) async {
    _activeSessions.remove(sessionId);
    if (db != null) {
      await db!.sessionMutexDao.unlock(sessionId);
    }
  }

  Future<void> _startChat(Map<String, dynamic> data) async {
    _log.info('🚀 Starting agent loop');
    String? sessionId;

    try {
      sessionId = data['sessionId'] as String?;
    } catch (e) {
      channel.sendCustomMessage({
        'type': 'error',
        'message': 'Invalid session ID format: $e',
      });
      return;
    }

    if (sessionId != null) {
      final locked = await _lockSession(sessionId);
      if (!locked) {
        _log.warning('Chat already in progress for session $sessionId');
        channel.sendCustomMessage({
          'type': 'error',
          'message': 'Chat already in progress for session $sessionId',
        });
        return;
      }
    }

    try {
      try {
        final config = data['config'] as Map<String, dynamic>;
        final triggerMessageJson =
            data['triggerMessage'] as Map<String, dynamic>?;

        if (sessionId == null || db == null) {
          throw Exception(
            'Session ID and Database required',
          );
        }
        final currentSessionId = sessionId;

        // If we have a trigger message, upsert it immediately to ensure we have the latest context
        if (triggerMessageJson != null) {
          _log.info(
            '📥 Received trigger message, upserting...',
          );
          final triggerMessage = MessageEntity.fromJson(triggerMessageJson);
          await db!.messageDao.insertMessage(triggerMessage.toCompanion(true));
          _log.info(
            '✅ Trigger message ${triggerMessage.id} upserted!',
          );
        }

        // Always load conversation from database (single source of truth)
        // Filter out streaming placeholders to prevent confusing the LLM with empty assistant messages
        // Also filter out messages not visible to LLM
        final dbMessages =
            await db!.messageDao.getMessagesBySession(currentSessionId);
        final conversation = dbMessages
            .where((m) => !m.isStreaming && m.isVisibleToLlm)
            .map((m) => m.toChatMessage())
            .toList();

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

        final apiKey = config['apiKey'] as String;
        final providerTypeStr = config['provider'] as String;
        final model = config['model'] as String;
        final baseUrl = config['baseUrl'] as String?;
        final temperature = config['temperature'] as double?;
        final maxTokens = config['maxTokens'] as int?;
        final systemInstruction = config['systemInstruction'] as String?;

        final apiType = LlmApiType.values.firstWhere(
          (e) => e.name == providerTypeStr,
          orElse: () =>
              throw Exception('Unknown provider type: $providerTypeStr'),
        );

        final settings = LlmApiSettings(
          identifier: model,
          apiType: apiType,
          baseUrl: baseUrl ?? apiType.defaultBaseUrl,
          temperature: temperature,
          maxTokens: maxTokens,
        );

        final provider = await LlmService.createProvider(
          settings,
          apiKey,
          systemInstruction: systemInstruction,
        );

        _currentCancelToken = CancelToken();

        await runAgentLoop(
          llmStream: (conv, tools, {cancelToken}) {
            return provider.chatStream(
              conv,
              tools: tools,
              cancelToken: cancelToken,
            );
          },
          tools: shellTools,
          conversation: conversation,
          cancelToken: _currentCancelToken,
          requestApproval: (pendingCalls) {
            _currentPendingCalls = pendingCalls;

            channel.sendCustomMessage({
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
          executeToolCall: (toolCall) async {
            final argumentsJson = toolCall.function.arguments;
            final params = argumentsJson.isNotEmpty
                ? Map<String, dynamic>.from(jsonDecode(argumentsJson))
                : <String, dynamic>{};

            if (toolCall.function.name == kExecuteShellCommand) {
              final command = params['command'] as String;
              final secrets = params['secrets'] != null
                  ? Map<String, String>.from(params['secrets'])
                  : null;
              final result =
                  await _shellService.executeCommand(command, secrets: secrets);
              await db!.sessionDao.touchSession(currentSessionId);
              return jsonEncode(result);
            } else if (toolCall.function.name == kFetch) {
              final result = await FetchTool.execute(params);
              await db!.sessionDao.touchSession(currentSessionId);
              return jsonEncode(result['data']);
            }

            return jsonEncode({'error': 'Unknown tool'});
          },
          onTextDelta: (delta) {
            if (_streamingMessageId == null) {
              _streamingMessageId = db!.messageDao.generateMessageId();
              _streamingCreatedAt = DateTime.now();
            }
            _streamingContent.write(delta);
            final content = _streamingContent.toString();
            final id = _streamingMessageId!;
            final createdAt = _streamingCreatedAt!;

            // Capture values for the closure
            final companion = MessageEntityCompanion(
              id: Value(id),
              sessionId: Value(currentSessionId),
              userId: const Value('ai'),
              userName: Value(model),
              content: Value(content),
              timestamp: Value(createdAt),
              createdAt: Value(createdAt),
              messageKind: const Value(MessageKind.text),
              isStreaming: const Value(true),
            );

            _lastDbWrite = _lastDbWrite.then((_) async {
              await db!.messageDao.insertMessage(companion);
            }).catchError((e) {
              _log.warning(
                'Error writing streaming message: $e',
              );
              // Return void to satisfy the Future<void> chain
            });
          },
          onAssistantMessage: (message, {String? messageId}) async {
            // Wait for any pending streaming writes to finish
            await _lastDbWrite;

            String? id =
                _streamingMessageId ?? db!.messageDao.generateMessageId();

            // db and sessionId are guaranteed to be non-null here due to checks at start of method
            // Determine if this is a tool use message or a text message
            final messageType = message.messageType;
            if (messageType is ToolUseMessage) {
              await db!.messageDao.insertMessage(
                message.toMessageCompanion(
                  sessionId: currentSessionId,
                  id: id,
                  userName: model,
                ),
              );
            } else {
              await db!.messageDao.insertMessageWithId(
                id: id,
                sessionId: currentSessionId,
                userId: 'ai',
                userName: model,
                content: message.content,
                isStreaming: false,
              );
            }
            await db!.sessionDao.touchSession(currentSessionId);
          },
          onToolResultMessage: (
            message, {
            String? messageId,
            ChatMessage? toolCallMessage,
          }) async {
            String? id;
            // db and sessionId are guaranteed to be non-null here due to checks at start of method
            id = db!.messageDao.generateMessageId();
            await db!.messageDao.insertMessage(
              message.toMessageCompanion(
                sessionId: currentSessionId,
                id: id,
                toolCallMessage: toolCallMessage,
              ),
            );
            await db!.sessionDao.touchSession(currentSessionId);
          },
        );

        channel.sendCustomMessage({'type': 'complete'});
      } catch (e, st) {
        if (e is CancelledError) {
          _log.info('Agent loop cancelled by user');
          channel.sendCustomMessage({'type': 'cancelled'});
        } else {
          _log.severe('Error running agent loop: $e, $st');

          final messageId = db!.messageDao.generateMessageId();

          // Try to insert error message if we have session ID and DB
          if (sessionId != null && db != null) {
            try {
              final config = data['config'] as Map<String, dynamic>?;
              final model = config?['model'] as String? ?? 'Ops Agent';

              await db!.messageDao.insertMessageWithId(
                id: messageId,
                sessionId: sessionId,
                userId: 'ai',
                userName: model,
                content: 'Sorry, I encountered an error: $e',
                isVisibleToLlm: false,
              );
              await db!.sessionDao.touchSession(sessionId);
            } catch (innerE) {
              _log.severe('Failed to insert error message: $innerE');
            }
          }

          channel.sendCustomMessage({
            'type': 'error',
            'message_id': messageId,
            'message': e.toString(),
          });
        }
      } finally {
        _currentCancelToken = null;

        // Ensure any pending DB writes are finished before unlocking
        try {
          await _lastDbWrite;
        } catch (e) {
          _log.warning('Error waiting for last DB write: $e');
        }

        if (_streamingMessageId != null && db != null) {
          // Clean up any streaming message placeholder
          try {
            final config = data['config'] as Map<String, dynamic>?;
            final model = config?['model'] as String? ?? 'Ops Agent';

            await db!.messageDao.insertMessageWithId(
              id: _streamingMessageId!,
              sessionId: sessionId!,
              userId: 'ai',
              userName: model,
              content: _streamingContent.toString(),
              isStreaming: false,
              isVisibleToLlm: true,
            );
          } catch (e) {
            _log.warning(
              'Error cleaning up streaming message placeholder: $e',
            );
          }
        }
        // Reset streaming state
        _streamingMessageId = null;
        _streamingContent.clear();
        _streamingCreatedAt = null;
        _lastDbWrite = Future.value(); // Reset chain

        if (sessionId != null) {
          await _unlockSession(sessionId);
        }
      }
    } catch (e) {
      _log.severe('Error starting chat', e);
      channel.sendCustomMessage({
        'type': 'error',
        'message': e.toString(),
      });
      if (sessionId != null) {
        await _unlockSession(sessionId);
      }
    }
  }
}
