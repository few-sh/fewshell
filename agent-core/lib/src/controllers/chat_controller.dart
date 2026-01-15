import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:state_notifier/state_notifier.dart';
import 'package:llm_dart/llm_dart.dart';
import 'package:drift/drift.dart';
import 'package:async/async.dart';

import '../../agent_core.dart';

// Constants for message user IDs
const String _kUserUserId = 'user';
const String _kUserUserName = 'You';
const String _kAiUserId = 'ai';
const String _kAiUserName = 'Ops Agent';

/// Controller for chat session state management
/// Handles all business logic for chat interactions, tool execution, and message syncing
/// Directly calls DAOs and services without unnecessary repository layer
class ChatController extends StateNotifier<ChatState> {
  static final _log = Logger('ChatController');

  final MessageDao _messageDao;
  final SessionDao _sessionDao;
  final SessionMutexDao? _sessionMutexDao;
  final LlmService _llmService;
  final ShellService _shellService;
  final SecretRedactor _secretRedactor;
  final SshSettings? _sshSettings;
  final ProjectEntity? _project;
  final String? sessionId;

  final _activeMessageController = StreamController<MessageEntity>.broadcast();
  StreamController<ProcessSignal>? _currentAbortController;
  CancelToken? _currentLlmCancelToken;
  bool _isAborted = false;

  Stream<MessageEntity> get activeMessageStream =>
      _activeMessageController.stream;

  /// Stream of the currently streaming message (if any)
  /// Merges local updates (activeMessageStream) and remote updates (from DB)
  Stream<MessageEntity?> get streamingMessageStream {
    if (sessionId == null) return const Stream.empty();

    final dbStream = _messageDao
        .watchStreamingMessagesBySession(sessionId!)
        .map((list) => list.firstOrNull);

    return StreamGroup.merge([activeMessageStream, dbStream]);
  }

  ChatController({
    required MessageDao messageDao,
    required SessionDao sessionDao,
    SessionMutexDao? sessionMutexDao,
    required LlmService llmService,
    required ShellService shellService,
    required SecretRedactor secretRedactor,
    SshSettings? sshSettings,
    ProjectEntity? project,
    this.sessionId,
  })  : _messageDao = messageDao,
        _sessionDao = sessionDao,
        _sessionMutexDao = sessionMutexDao,
        _llmService = llmService,
        _shellService = shellService,
        _secretRedactor = secretRedactor,
        _sshSettings = sshSettings,
        _project = project,
        super(const ChatState());

  @override
  void dispose() {
    _activeMessageController.close();
    super.dispose();
  }

  /// Reset state when session changes (called by provider when session changes)
  void resetForNewSession() {
    state = const ChatState();
  }

  /// Abort the currently running command
  void abortCommand(MultiplexedWebSocketChannel? syncChannel) {
    _log.info('Aborting command...');
    _isAborted = true;
    _currentAbortController?.add(ProcessSignal.sigterm);
    _currentLlmCancelToken?.cancel('Aborted by user');

    if (syncChannel != null) {
      _log.info('Sending abort_chat to server');
      syncChannel.sendCustomMessage({'type': 'abort_chat'});
    }
  }

  /// Build conversation history from database messages
  /// Reconstructs proper ChatMessage objects including tool use and tool results
  List<ChatMessage> _buildConversationHistory(List<dynamic> dbMessages) {
    final conversation = <ChatMessage>[];

    _log.info(
      '🔄 Building conversation history from ${dbMessages.length} messages',
    );

    for (final msg in dbMessages) {
      // Cast to MessageEntity for type-safe access
      final messageEntity = msg as MessageEntity;

      // Skip streaming messages (placeholders) to prevent sending empty/partial messages to LLM
      if (messageEntity.isStreaming) {
        continue;
      }

      // Skip messages that are not visible to LLM
      if (!messageEntity.isVisibleToLlm) {
        continue;
      }

      // Use the extension method to convert to ChatMessage
      final chatMessage = messageEntity.toChatMessage();

      _log.info(
        '✅ Reconstructed ${chatMessage.role.name} message with kind: ${messageEntity.messageKind.name}',
      );

      // Log tool calls and results for debugging
      if (chatMessage.messageType is ToolUseMessage) {
        final toolUse = chatMessage.messageType as ToolUseMessage;
        _log.info(
          '  🔧 Tool calls: ${toolUse.toolCalls.map((tc) => tc.function.name).join(", ")}',
        );
      } else if (chatMessage.messageType is ToolResultMessage) {
        final toolResult = chatMessage.messageType as ToolResultMessage;
        _log.info(
          '  📊 Tool results: ${toolResult.results.length} result(s)',
        );
      }

      conversation.add(chatMessage);
    }

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

    _log.info(
      '✅ Built conversation with ${conversation.length} messages',
    );

    return conversation;
  }

  /// Validate and prepare for sending a message
  Future<MessageEntity?> _validateAndPrepare({
    required String sessionId,
    required String content,
    String? userName,
  }) async {
    // Redact and save user's message
    final redactedContent = await _secretRedactor.redact(content);
    final messageId = await _messageDao.insertMessageWithId(
      sessionId: sessionId,
      userId: _kUserUserId,
      userName: userName ?? _kUserUserName,
      content: redactedContent,
    );

    // Update session description if it's empty or default (first message)
    final session = await _sessionDao.getSession(sessionId);
    final currentDescription = session?.description ?? '';
    if (currentDescription.isEmpty ||
        currentDescription == kDefaultSessionDescription) {
      final description =
          content.length > 495 ? '${content.substring(0, 495)}...' : content;
      await _sessionDao.updateSession(
        SessionEntityCompanion(
          id: Value(sessionId),
          description: Value(description),
        ),
      );
    }

    // Check if LLM is configured
    final isConfigured = await _llmService.isConfigured();
    if (!isConfigured) {
      return null;
    }

    return _messageDao.getMessage(messageId);
  }

  /// Convert PendingToolCall to ToolAction for UI approval
  List<ToolAction> _pendingToolCallsToActions(List<PendingToolCall> toolCalls) {
    return toolCalls.map((tc) {
      return ToolAction(id: tc.id, toolName: tc.name, params: tc.arguments);
    }).toList();
  }

  /// Send a message to the AI
  /// Handles saving to database, getting AI response, and managing tool calls
  ///
  /// If content is null, resends the last user message in the conversation.
  /// This is used for resend/edit operations.
  ///
  /// For local execution, acquires a session lock via SessionMutexDao.
  /// For remote execution, the server manages the lock.
  Future<void> sendMessage({
    String? content,
    String? userName,
    MessageEntity? triggerMessage,
    required String sessionId,
    required Future<List<ToolAction>?> Function(List<ToolAction>)
        requestApproval,
    void Function()? onNoConfig,
    MultiplexedWebSocketChannel? syncChannel,
  }) async {
    // Clear any previous error
    if (mounted) state = state.copyWith(error: null);

    // For local execution (no server), acquire lock via mutex
    // For remote execution, server handles locking
    final isLocalExecution = _project?.serverUrl == null;
    if (isLocalExecution && _sessionMutexDao != null) {
      final acquired = await _sessionMutexDao.acquireLock(sessionId);
      if (!acquired) {
        _log.warning('Could not acquire lock for session $sessionId');
        if (mounted) {
          state = state.copyWith(error: 'Session is busy');
        }
        return;
      }
    }

    try {
      // If content is provided, validate and save the new user message
      if (content != null) {
        triggerMessage = await _validateAndPrepare(
          sessionId: sessionId,
          content: content,
          userName: userName,
        );
        if (triggerMessage == null) {
          onNoConfig?.call();
          return;
        }
      }

      var aiMessageId = _messageDao.generateMessageId();
      String? currentToolMessageId;
      MessageEntity? currentEntity;

      // Get initial entity
      currentEntity = await _messageDao.getMessage(aiMessageId);

      // Get config for remote execution
      final config = await _llmService.getActiveConfigSnapshot();
      if (config == null) {
        onNoConfig?.call();
        return;
      }

      // Define callbacks to be used by both local and remote loops
      Future<List<PendingToolCall>?> handleRequestApproval(
          List<PendingToolCall> pendingCalls) async {
        // Convert to UI's ToolAction format
        final actions = _pendingToolCallsToActions(pendingCalls);
        final selectedActions = await requestApproval(actions);

        if (selectedActions == null) {
          return null; // User cancelled
        }

        _log.info(
          '✅ User approved ${selectedActions.length} tool calls',
        );

        // Return the approved subset of PendingToolCalls with updated arguments
        final pendingCallsById = {for (var pc in pendingCalls) pc.id: pc};
        return selectedActions
            .map((action) {
              final original = pendingCallsById[action.id];
              if (original == null) {
                _log.warning(
                  'Could not find original pending call for action id: ${action.id}',
                );
                return null;
              }
              return PendingToolCall(
                id: original.id,
                name: original.name,
                arguments: action.params,
                originalToolCall: original.originalToolCall,
              );
            })
            .whereType<PendingToolCall>()
            .toList();
      }

      Future<void> handleAssistantMessage(ChatMessage message,
          {String? messageId}) async {
        // Use the ID provided by server, or generate one if local
        final idToUse = messageId ?? aiMessageId;

        // Determine if this is a tool use message or a text message
        final messageType = message.messageType;
        if (messageType is ToolUseMessage) {
          // Save tool use message
          final aiUserName = await _getAiUserName();
          await _messageDao.insertMessage(
            message.toMessageCompanion(
              sessionId: sessionId,
              id: idToUse,
              userName: aiUserName,
            ),
          );
          currentToolMessageId = idToUse;
        } else {
          // Save text message
          final redactedContent = await _secretRedactor.redact(
            message.content,
          );
          final aiUserName = await _getAiUserName();
          await _messageDao.insertMessageWithId(
            id: idToUse,
            sessionId: sessionId,
            userId: _kAiUserId,
            userName: aiUserName,
            content: redactedContent,
          );
          currentToolMessageId = null;
        }

        await _sessionDao.touchSession(sessionId);

        // Update current entity for next steps
        currentEntity = await _messageDao.getMessage(idToUse);

        // Generate new ID for next message (only used if local or if server didn't provide one)
        aiMessageId = _messageDao.generateMessageId();
      }

      Future<void> handleToolResultMessage(ChatMessage message,
          {String? messageId, ChatMessage? toolCallMessage}) async {
        // Use the ID provided by server, or generate one if local
        final idToUse = messageId ?? _messageDao.generateMessageId();

        await _messageDao.insertMessage(
          message.toMessageCompanion(
            sessionId: sessionId,
            id: idToUse,
            toolCallMessage: toolCallMessage,
          ),
        );

        await _sessionDao.touchSession(sessionId);

        // Update current entity
        currentEntity = await _messageDao.getMessage(idToUse);
      }

      final AgentLoopResult result;

      if (_project?.serverUrl != null) {
        if (syncChannel == null) {
          if (mounted) {
            state = state.copyWith(
              // TODO: Use a centralized error notification and logging system
              error: 'Cannot start remote chat: not connected to server',
            );
          }
          throw Exception(
            'Cannot start remote chat: not connected to server',
          );
        }

        // Ensure we have a triggerMessage
        triggerMessage ??= await _messageDao.getLastMessage(sessionId);

        if (triggerMessage == null) {
          if (mounted) {
            state = state.copyWith(
              error: 'Cannot start remote chat: no context',
            );
          }
          return;
        }

        // Run the agent loop remotely
        result = await runRemoteAgentLoop(
          channel: syncChannel,
          config: config,
          sessionId: sessionId,
          triggerMessage: triggerMessage,
          requestApproval: handleRequestApproval,
        );
      } else {
        // Run the agent loop locally
        // Get conversation history
        final dbMessages = await _messageDao.getMessagesBySession(sessionId);
        final conversation = _buildConversationHistory(dbMessages);

        _currentLlmCancelToken = CancelToken();

        try {
          result = await runAgentLoop(
            llmStream: (conv, tools, {cancelToken}) => _llmService.streamChat(
              conv,
              tools: tools,
              cancelToken: cancelToken,
            ),
            tools: shellTools,
            conversation: conversation,
            cancelToken: _currentLlmCancelToken,
            getConversation: () async {
              // Rebuild conversation from database each iteration (single source of truth)
              final dbMessages =
                  await _messageDao.getMessagesBySession(sessionId);
              return _buildConversationHistory(dbMessages);
            },
            requestApproval: handleRequestApproval,
            executeToolCall: (toolCall) async {
              if (currentToolMessageId != null) {
                // Refresh current entity just in case
                currentEntity =
                    await _messageDao.getMessage(currentToolMessageId!);
              }

              final toolOutputBuffer = StringBuffer();
              void onOutput(String data) {
                toolOutputBuffer.write(data);
                if (currentEntity != null) {
                  // Construct display content: original content + code block with output
                  final displayContent =
                      '${currentEntity!.content}\n\n```\n${toolOutputBuffer.toString()}\n```';
                  _activeMessageController.add(
                    currentEntity!.copyWith(content: displayContent),
                  );
                }
              }

              // Execute and return result as JSON string
              final result =
                  await _executeToolCall(toolCall, onOutput: onOutput);
              await _sessionDao.touchSession(sessionId);
              return jsonEncode(result);
            },
            onAssistantMessage: handleAssistantMessage,
            onToolResultMessage: handleToolResultMessage,
          );
        } finally {
          _currentLlmCancelToken = null;
        }
      }

      // Handle result
      switch (result) {
        case AgentLoopCompleted():
          _log.info('✅ Agent loop completed');
        case AgentLoopCancelled():
          _log.info(
            '🚨 User cancelled tool execution',
          );
        case AgentLoopError(
            message: final errorMsg,
            messageId: final messageId
          ):
          if (mounted) {
            state = state.copyWith(error: errorMsg);
          }
          final errorMessage = 'Sorry, I encountered an error: $errorMsg';
          final redactedError = await _secretRedactor.redact(errorMessage);
          final aiUserName = await _getAiUserName();
          await _messageDao.insertMessageWithId(
            id: messageId,
            sessionId: sessionId,
            userId: _kAiUserId,
            userName: aiUserName,
            content: redactedError,
            isVisibleToLlm: false,
          );
          await _sessionDao.touchSession(sessionId);
          return;
      }
    } catch (e) {
      if (e is CancelledError) {
        _log.info('Operation cancelled by user');
        return;
      }

      // TODO: Should not try to get ai usernme and use 'System' instead
      final errorMessage = 'Sorry, I encountered an error: $e';
      final redactedError = await _secretRedactor.redact(errorMessage);
      final aiUserName = await _getAiUserName();
      await _messageDao.insertMessageWithId(
        sessionId: sessionId,
        userId: _kAiUserId,
        userName: aiUserName,
        content: redactedError,
        isVisibleToLlm: false,
      );
      await _sessionDao.touchSession(sessionId);
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
    } finally {
      // Release lock for local execution
      if (isLocalExecution && _sessionMutexDao != null) {
        await _sessionMutexDao.unlock(sessionId);
      }
    }
  }

  /// Execute a single tool call and return result as Map
  Future<Map<String, dynamic>> _executeToolCall(
    ToolCall toolCall, {
    void Function(String)? onOutput,
  }) async {
    final argumentsJson = toolCall.function.arguments;
    final params = argumentsJson.isNotEmpty
        ? Map<String, dynamic>.from(jsonDecode(argumentsJson))
        : <String, dynamic>{};

    final result = await _executeAction(
      toolCall.function.name,
      params,
      onOutput: onOutput,
    );
    return result['data'] as Map<String, dynamic>;
  }

  /// Execute a single action (shell command or fetch)
  Future<Map<String, dynamic>> _executeAction(
    String actionName,
    Map<String, dynamic> params, {
    void Function(String)? onOutput,
  }) async {
    if (actionName == kExecuteShellCommand) {
      final command = params['command'] as String;
      final sudoRequired = params['sudo_required'] as bool? ?? false;
      final secrets = params['secrets'] != null
          ? List<String>.from(params['secrets'] as List)
          : null;

      Map<String, dynamic> result;

      _currentAbortController = StreamController<ProcessSignal>.broadcast();
      _isAborted = false;

      try {
        if (sudoRequired) {
          result = await _shellService.executeWithSudo(
            command: command,
            sudoPasswordSecretId: _sshSettings?.sudoPasswordSecretId ??
                _sshSettings?.passwordSecretId,
            secrets: secrets,
            abortSignal: _currentAbortController!.stream,
            onStdout: (data) => onOutput?.call(data),
            onStderr: (data) => onOutput?.call(data),
          );
        } else {
          result = await _shellService.executeCommand(
            command,
            secrets: secrets,
            abortSignal: _currentAbortController!.stream,
            onStdout: (data) => onOutput?.call(data),
            onStderr: (data) => onOutput?.call(data),
          );
        }
      } catch (e) {
        // Handle exceptions by returning an error result that can be sent to the LLM
        final errorMessage =
            e.toString().replaceFirst(RegExp(r'^Exception: '), '');
        result = {
          'stdout': '',
          'stderr': 'Error executing command: $errorMessage',
          'exitCode': -1,
          'executed': false,
        };
      } finally {
        await _currentAbortController?.close();
        _currentAbortController = null;
      }

      if (_isAborted) {
        _isAborted = false;
        return {
          'success': false,
          'data': result,
          'error': 'Command execution aborted by user',
        };
      }

      return {
        'success': (result['exitCode'] as int? ?? -1) == 0,
        'data': result,
        'error': result['stderr'] as String?,
      };
    }

    if (actionName == kFetch) {
      return FetchTool.execute(params);
    }

    throw Exception('Unknown action: $actionName');
  }

  /// Edit a message and resend from that point
  /// Updates the message content, deletes all messages after it, then resends
  Future<void> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    _log.info('✏️ Editing message: $messageId');

    // Get the message to find its timestamp
    final message = await _messageDao.getMessage(messageId);
    if (message == null) {
      _log.warning('❌ Message not found: $messageId');
      return;
    }

    // Update the message content
    final updatedMessage = await _messageDao.updateMessageContent(
      messageId: messageId,
      newContent: newContent,
    );

    if (updatedMessage == null) {
      _log.warning('❌ Failed to update message: $messageId');
      return;
    }

    _log.info('💾 Updated message content');
  }

  /// Resend a message: delete all messages after it, then resend from that point
  Future<void> resendMessage({
    required String messageId,
    required String sessionId,
    required Future<List<ToolAction>?> Function(List<ToolAction>)
        requestApproval,
    MultiplexedWebSocketChannel? syncChannel,
  }) async {
    _log.info(
      '🔄 Resending from message: $messageId',
    );

    // Get the message to find its timestamp
    final message = await _messageDao.getMessage(messageId);
    if (message == null) {
      _log.warning('❌ Message not found: $messageId');
      return;
    }

    // Delete all messages AFTER this one (keep the message itself)
    final deletedCount = await _messageDao.deleteMessagesAfter(
      sessionId: sessionId,
      afterTimestamp: message.timestamp,
    );

    _log.info(
      '🗑️ Deleted $deletedCount messages after target, now resending',
    );

    // Resend - conversation will include the message we're resending from
    await sendMessage(
      content: null, // Use existing conversation
      triggerMessage: message,
      sessionId: sessionId,
      requestApproval: requestApproval,
      syncChannel: syncChannel,
    );
  }

  /// Delete a single message
  Future<void> deleteMessage(String messageId) async {
    _log.info('🗑️ Deleting message: $messageId');
    await _messageDao.deleteMessage(messageId);
  }

  /// Branch the session by creating a copy up to a specific message
  /// Returns the new session ID
  Future<String> branchSession({
    required String messageId,
    required String sessionId,
  }) async {
    _log.info(
      '🌿 Branching session at message: $messageId',
    );

    final newSessionId = await _sessionDao.branchSession(
      sessionId: sessionId,
      upToMessageId: messageId,
    );

    _log.info(
      '✅ Created new session: $newSessionId',
    );

    return newSessionId;
  }

  /// Clear error state
  void clearError() {
    if (mounted) state = state.copyWith(error: null);
  }

  /// Get the AI username based on the active model identifier
  Future<String> _getAiUserName() async {
    try {
      final modelId = await _llmService.getActiveModelIdentifier();
      return modelId ?? _kAiUserName;
    } catch (e) {
      _log.warning('Failed to get AI username: $e');
      return _kAiUserName;
    }
  }
}
