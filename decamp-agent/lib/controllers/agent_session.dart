import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:drift/drift.dart';
import 'package:llm_dart/llm_dart.dart';
import 'package:logging/logging.dart';

import '../services/interactive_shell_session.dart';
import '../services/local_shell_backend.dart';
import '../services/notification_dispatcher.dart';

class AgentSession {
  static final _log = Logger('AgentSession');
  static const _pendingToolCallsObjectKind = 'pending_tool_calls';
  static const _pendingToolCallsObjectKey = 'active';

  /// Set of active channels for this session (supports reconnections)
  final Set<MultiplexedWebSocketChannel> _channels = {};

  final GlobalDatabase globalDb;
  final ProjectDatabase? projectDb;
  final String projectId;
  final KeychainService _keychainService;
  final NotificationDispatcher _notificationDispatcher;
  final void Function() onComplete;
  Completer<PendingToolCallList?>? _approvalCompleter;
  PendingToolCallList? _currentPendingCalls;
  StateReplicator<PendingToolCallList>? _pendingToolCallsReplicator;
  void Function()? _removePendingToolCallsListener;
  CancelToken? _currentCancelToken;
  StreamController<ProcessSignal>? _currentAbortController;

  /// The shared interactive shell session
  late final InteractiveShellSession _interactiveSession;

  Future<void> _lastDbWrite = Future.value();

  AgentSession(
    this.globalDb,
    this.projectDb,
    this.projectId,
    KeychainService keychain, {
    required NotificationDispatcher notificationDispatcher,
    required this.onComplete,
  })  : _notificationDispatcher = notificationDispatcher,
        _keychainService = keychain {
    _interactiveSession = InteractiveShellSession(
      shellService: ShellService(
        null,
        _keychainService,
        projectId,
        backend: LocalShellBackend(),
      ),
      onOutput: (data) {
        for (final channel in _channels) {
          channel.safeSendCustomMessage({
            'type': 'terminal_output',
            'data': data,
          });
        }
      },
      onSessionEnded: () {
        for (final channel in _channels) {
          channel.safeSendCustomMessage({
            'type': 'terminal_session_ended',
          });
        }
      },
    );
  }

  /// Register a new channel with this session (handles reconnections)
  void registerChannel(MultiplexedWebSocketChannel channel) {
    _channels.add(channel);
    _log.info(
      'Registered channel with session. Total channels: ${_channels.length}',
    );
  }

  /// Unregister a channel from this session
  /// Returns true if the channel was registered with this session
  bool unregisterChannel(MultiplexedWebSocketChannel channel) {
    final wasRegistered = _channels.remove(channel);
    if (wasRegistered) {
      _log.info(
        'Unregistered channel from session. Remaining channels: ${_channels.length}',
      );
    }
    return wasRegistered;
  }

  /// Check if this session has any active channels
  bool get hasActiveChannels => _channels.isNotEmpty;

  void _broadcastCustomMessage(Map<String, dynamic> message) {
    for (final channel in _channels) {
      channel.safeSendCustomMessage(message);
    }
  }

  void dispose() {
    _currentCancelToken?.cancel('Session disposed');
    _currentCancelToken = null;
    unawaited(_currentAbortController?.close());
    _currentAbortController = null;
    unawaited(_disposePendingToolCallsReplicator());
    _interactiveSession.close();
  }

  void handleMessage(
    Map<String, dynamic> msg,
    MultiplexedWebSocketChannel channel,
  ) {
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
    } else if (msg['type'] == StateReplicatedEnvelope.messageType) {
      _handleReplicatedState(msg);
    } else if (msg['type'] == 'abort_chat') {
      _handleAbort(msg);
    } else if (msg['type'] == 'terminal_keys') {
      _handleTerminalKeys(msg);
    }
  }

  void _handleAbort(Map<String, dynamic> data) {
    _log.info('🛑 Received abort request');
    _currentCancelToken?.cancel('Aborted by user');
    _currentAbortController?.add(ProcessSignal.sigint);

    // If there's a pending approval request, cancel it so the agent loop
    // can unblock and terminate cleanly.
    if (_approvalCompleter != null && !_approvalCompleter!.isCompleted) {
      _log.info('Cancelling pending approval request due to abort');
      _approvalCompleter!.complete(null);
    }
    _clearPendingApprovalState();
  }

  /// Handle terminal key input from the client
  void _handleTerminalKeys(Map<String, dynamic> data) {
    final keyData = data['data'];
    if (keyData is! List) {
      _log.warning('Received terminal_keys with invalid data type');
      return;
    }
    final bytes = Uint8List.fromList(List<int>.from(keyData));
    _interactiveSession.writeKeys(bytes);
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

    final completer = _approvalCompleter;
    if (completer != null && !completer.isCompleted) {
      if (data['approvedCalls'] != null &&
          data['approvedCalls'] is List &&
          data['approvedCalls'].isNotEmpty) {
        final approvedCalls =
            (data['approvedCalls'] as List).cast<Map<String, dynamic>>();
        final pending = _currentPendingCalls?.items ?? [];
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

              return original.withArguments(arguments);
            })
            .whereType<PendingToolCall>()
            .toList();

        _clearPendingApprovalState();
        completer.complete(PendingToolCallList(approved));
      } else {
        // Cancelled
        _clearPendingApprovalState();
        completer.complete(null);
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

  void _handleReplicatedState(Map<String, dynamic> message) {
    final replicator = _pendingToolCallsReplicator;
    if (replicator == null) {
      return;
    }

    if (replicator.tryApplyMessage(message)) {
      unawaited(replicator.syncCurrent());
    }
  }

  void _clearPendingApprovalState() {
    final replicator = _pendingToolCallsReplicator;
    if (replicator != null) {
      unawaited(replicator.sendAction(StateReplicatedAction.closed));
    }
    unawaited(_disposePendingToolCallsReplicator());
    _approvalCompleter = null;
    _currentPendingCalls = null;
  }

  bool get _isAwaitingApproval =>
      _approvalCompleter != null && !_approvalCompleter!.isCompleted;

  void _sendApprovalRequest(
    MultiplexedWebSocketChannel channel,
    PendingToolCallList pendingCalls, {
    required String sessionId,
  }) {
    channel.safeSendCustomMessage({
      'type': 'request_approval',
      'tools': pendingCalls.items
          .map((call) => call.toApprovalRequestJson())
          .toList(),
      'sessionId': sessionId,
    });
  }

  Future<PendingToolCallList?> _requestApproval(
    PendingToolCallList pendingCalls, {
    required String sessionId,
  }) {
    _currentPendingCalls = pendingCalls;
    _createPendingToolCallsReplicator(
      sessionId: sessionId,
      pendingCalls: pendingCalls,
    );

    final completer = Completer<PendingToolCallList?>();
    _approvalCompleter = completer;
    final replicator = _pendingToolCallsReplicator;
    if (replicator != null) {
      unawaited(replicator.syncCurrent());
    }
    _broadcastCustomMessage({
      'type': 'request_approval',
      'tools': pendingCalls.items
          .map((call) => call.toApprovalRequestJson())
          .toList(),
      'sessionId': sessionId,
    });

    return completer.future;
  }

  bool _resendPendingApprovalRequest(
    MultiplexedWebSocketChannel channel, {
    required String sessionId,
  }) {
    if (!_isAwaitingApproval) {
      return false;
    }

    final pendingCalls = _currentPendingCalls;
    if (pendingCalls == null || pendingCalls.items.isEmpty) {
      _log.warning(
        'Approval state exists, but there are no pending tool calls',
      );
      return false;
    }

    _log.info('Re-sending pending approval request to reconnected channel');
    final replicator = _pendingToolCallsReplicator;
    if (replicator != null) {
      unawaited(replicator.syncCurrent());
    }
    _sendApprovalRequest(channel, pendingCalls, sessionId: sessionId);
    return true;
  }

  void _createPendingToolCallsReplicator({
    required String sessionId,
    required PendingToolCallList pendingCalls,
  }) {
    _removePendingToolCallsListener?.call();
    _removePendingToolCallsListener = null;
    unawaited(_pendingToolCallsReplicator?.dispose());

    final replicator = StateReplicator<PendingToolCallList>(
      sessionId: sessionId,
      objectKind: _pendingToolCallsObjectKind,
      objectKey: _pendingToolCallsObjectKey,
      decode: PendingToolCallList.fromJson,
      initialState: pendingCalls,
      sendEnvelope: (envelope) => _broadcastCustomMessage(envelope.toJson()),
      errorHandler: (error, stackTrace) {
        _log.warning(
          'Pending tool call replication error',
          error,
          stackTrace,
        );
      },
    );
    _pendingToolCallsReplicator = replicator;
    _removePendingToolCallsListener = replicator.onChanged(
      (next, previous) {
        _currentPendingCalls = next;
      },
      fireImmediately: true,
    );
  }

  Future<void> _disposePendingToolCallsReplicator() async {
    _removePendingToolCallsListener?.call();
    _removePendingToolCallsListener = null;
    final replicator = _pendingToolCallsReplicator;
    _pendingToolCallsReplicator = null;
    if (replicator != null) {
      await replicator.dispose();
    }
  }

  Future<void> _startChat(
    Map<String, dynamic> data,
    MultiplexedWebSocketChannel channel,
  ) async {
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
    if (projectDb != null) {
      final project = await globalDb.projectDao.getProject(projectId);
      if (project != null) {
        projectName = project.name;
      }
    }

    if (sessionId != null) {
      final locked = await _lockSession(sessionId);
      if (!locked) {
        if (_resendPendingApprovalRequest(channel, sessionId: sessionId)) {
          return;
        }
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
        final toolSummarizer = ToolSummarizer(
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
          cancelToken: _currentCancelToken!,
          toolSummarizer: toolSummarizer,
          requestApproval: (pendingCalls) =>
              _requestApproval(pendingCalls, sessionId: currentSessionId),
          executeToolCall: (toolUseMessage, approvedToolCalls) async {
            final results = <String>[];
            final completedToolResults = <ToolCall>[];

            streamingMessage = toolUseMessage.copyWith(
              messageKind: MessageKind.toolResult,
              isStreaming: true,
              // Keep the full original tool-use list for provider validation.
              toolCallsJson: Value(toolUseMessage.toolCallsJson),
            );

            for (final toolCall in approvedToolCalls) {
              final argumentsJson = toolCall.function.arguments;
              final params = argumentsJson.isNotEmpty
                  ? Map<String, dynamic>.from(jsonDecode(argumentsJson))
                  : <String, dynamic>{};

              String result;
              if (toolCall.function.name == kExecuteShellCommand) {
                final command = params['command'] as String;
                _log.info(
                  'Executing shell command on shared session. Abort controller: $abortController',
                );

                final sudoRequired = params['sudo_required'] as bool? ?? false;
                final secrets = params['secrets'] != null
                    ? List<String>.from(params['secrets'] as List)
                    : List<String>.empty();

                final envVars = await _keychainService.getProjectSecrets(
                  projectId,
                  secrets,
                );

                final secretRedactor =
                    SecretRedactor(_keychainService, projectId);
                await secretRedactor.load();

                final terminalBuffer = TerminalBuffer();
                void onOutput(String data) {
                  terminalBuffer.write(data);
                  final streamingResultJson = jsonEncode({
                    'stdout':
                        secretRedactor.redactSync(terminalBuffer.toString()),
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

                final shellResult = await _interactiveSession.executeCommand(
                  command: command,
                  abortSignal: abortController.stream,
                  onStdout: onOutput,
                  onStderr: onOutput,
                  environmentVars: envVars,
                  sudo: sudoRequired,
                );
                await _lastDbWrite.catchError((e) {
                  _log.warning(
                    'Error writing streaming message: $e',
                  );
                });
                await projectDb!.sessionDao.touchSession(currentSessionId);
                shellResult['stdout'] =
                    secretRedactor.redactSync(terminalBuffer.toString());
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
              toolCallMessage: toolCallMessage,
            );
            streamingMessage = streamingMessage.copyWith(
              messageKind: MessageKind.toolResult,
              toolCallsJson: Value(messageEntity.toolCallsJson),
              toolResultsJson: Value(messageEntity.toolResultsJson),
              isStreaming: false,
            );

            await projectDb!.messageDao
                .insertMessage(streamingMessage.toCompanion(true));

            final persisted = streamingMessage;

            // Generate new ID for next message (only used if local or if server didn't provide one)
            streamingMessage = streamingMessage.copyWith(
              id: projectDb!.messageDao.generateMessageId(),
            );

            await projectDb!.sessionDao.touchSession(currentSessionId);

            // Send push notification to subscribers
            unawaited(
              _notificationDispatcher.sendNotification(
                projectDb: projectDb!,
                projectId: projectId,
                sessionId: currentSessionId,
                messageId: id,
                title: 'Tool Execution Complete',
                body: 'A tool has finished executing in $projectName',
                data: {
                  'project_id': projectId,
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

            return persisted;
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

  Future<List<MessageEntity>> _loadConversation(String sessionId) async {
    // Always load conversation entities from database (single source of truth).
    return projectDb!.messageDao.getMessagesBySession(sessionId);
  }

  void _asyncDbWrite(Future<void> Function() write) {
    _lastDbWrite = _lastDbWrite.then((_) => write()).catchError((e) {
      _log.warning('Error writing streaming message: $e');
    });
  }
}
