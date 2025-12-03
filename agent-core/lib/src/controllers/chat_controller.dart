import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:state_notifier/state_notifier.dart';
import 'package:llm_dart/llm_dart.dart';
import 'package:drift/drift.dart';

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
  final MessageDao _messageDao;
  final SessionDao _sessionDao;
  final LlmService _llmService;
  final ShellService _shellService;
  final SecretRedactor _secretRedactor;
  final SshSettings? _sshSettings;
  final String? sessionId;

  ChatController({
    required MessageDao messageDao,
    required SessionDao sessionDao,
    required LlmService llmService,
    required ShellService shellService,
    required SecretRedactor secretRedactor,
    SshSettings? sshSettings,
    this.sessionId,
  })  : _messageDao = messageDao,
        _sessionDao = sessionDao,
        _llmService = llmService,
        _shellService = shellService,
        _secretRedactor = secretRedactor,
        _sshSettings = sshSettings,
        super(const ChatState());

  /// Reset state when session changes (called by provider when session changes)
  void resetForNewSession() {
    state = const ChatState();
  }

  /// Build conversation history from database messages
  /// Reconstructs proper ChatMessage objects including tool use and tool results
  List<ChatMessage> _buildConversationHistory(List<dynamic> dbMessages) {
    final conversation = <ChatMessage>[];

    developer.log(
      '🔄 Building conversation history from ${dbMessages.length} messages',
      name: 'ChatController',
    );

    for (final msg in dbMessages) {
      // Cast to MessageEntity for type-safe access
      final messageEntity = msg as MessageEntity;

      // Use the extension method to convert to ChatMessage
      final chatMessage = messageEntity.toChatMessage();

      developer.log(
        '✅ Reconstructed ${chatMessage.role.name} message with kind: ${messageEntity.messageKind.name}',
        name: 'ChatController',
      );

      // Log tool calls and results for debugging
      if (chatMessage.messageType is ToolUseMessage) {
        final toolUse = chatMessage.messageType as ToolUseMessage;
        developer.log(
          '  🔧 Tool calls: ${toolUse.toolCalls.map((tc) => tc.function.name).join(", ")}',
          name: 'ChatController',
        );
      } else if (chatMessage.messageType is ToolResultMessage) {
        final toolResult = chatMessage.messageType as ToolResultMessage;
        developer.log(
          '  📊 Tool results: ${toolResult.results.length} result(s)',
          name: 'ChatController',
        );
      }

      conversation.add(chatMessage);
    }

    developer.log(
      '✅ Built conversation with ${conversation.length} messages',
      name: 'ChatController',
    );

    return conversation;
  }

  /// Validate and prepare for sending a message
  Future<bool> _validateAndPrepare({
    required String sessionId,
    required String content,
  }) async {
    // Redact and save user's message
    final redactedContent = await _secretRedactor.redact(content);
    await _messageDao.insertMessageWithId(
      sessionId: sessionId,
      userId: _kUserUserId,
      userName: _kUserUserName,
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
      return false;
    }

    return true;
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
  /// Streaming is managed internally through ChatState:
  /// - startStreaming: Sets streamingMessageId in state
  /// - updateStreamingText: Updates streamingText in state
  /// - stopStreaming: Clears streaming state
  Future<void> sendMessage({
    String? content,
    required String sessionId,
    required Future<List<ToolAction>?> Function(List<ToolAction>)
        requestApproval,
    void Function()? onNoConfig,
    MultiplexedWebSocketChannel? syncChannel,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // If content is provided, validate and save the new user message
      if (content != null) {
        final isValid = await _validateAndPrepare(
          sessionId: sessionId,
          content: content,
        );
        if (!isValid) {
          state = state.copyWith(isLoading: false);
          onNoConfig?.call();
          return;
        }
      }

      var aiMessageId = _messageDao.generateMessageId();
      var hasStartedStreaming = false;
      final streamingBuffer = StringBuffer();

      // Get config for remote execution
      final config = await _llmService.getActiveConfigSnapshot();
      if (config == null) {
        state = state.copyWith(isLoading: false);
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

        developer.log(
          '✅ User approved ${selectedActions.length} tool calls',
          name: 'ChatController',
        );

        // Return the approved subset of PendingToolCalls
        return pendingCalls
            .where((pc) => selectedActions.any((a) => a.id == pc.id))
            .toList();
      }

      void handleTextDelta(String delta) {
        streamingBuffer.write(delta);
        if (!hasStartedStreaming) {
          startStreaming(aiMessageId);
          hasStartedStreaming = true;
        }
        updateStreamingText(streamingBuffer.toString());
      }

      Future<void> handleAssistantMessage(ChatMessage message,
          {String? messageId}) async {
        if (hasStartedStreaming) {
          stopStreaming();
          hasStartedStreaming = false;
          streamingBuffer.clear();
        }

        // Use the ID provided by server, or generate one if local
        final idToUse = messageId ?? aiMessageId;

        // Determine if this is a tool use message or a text message
        final messageType = message.messageType;
        if (messageType is ToolUseMessage) {
          // Save tool use message
          await _messageDao.insertMessage(
            message.toMessageCompanion(sessionId: sessionId, id: idToUse),
          );
        } else {
          // Save text message
          final redactedContent = await _secretRedactor.redact(
            message.content,
          );
          await _messageDao.insertMessageWithId(
            id: idToUse,
            sessionId: sessionId,
            userId: _kAiUserId,
            userName: _kAiUserName,
            content: redactedContent,
          );
        }

        // Generate new ID for next message (only used if local or if server didn't provide one)
        aiMessageId = _messageDao.generateMessageId();
      }

      Future<void> handleToolResultMessage(ChatMessage message,
          {String? messageId}) async {
        // Use the ID provided by server, or generate one if local
        final idToUse = messageId ?? _messageDao.generateMessageId();

        await _messageDao.insertMessage(
          message.toMessageCompanion(sessionId: sessionId, id: idToUse),
        );
      }

      final AgentLoopResult result;

      if (syncChannel != null) {
        // Run the agent loop remotely
        result = await runRemoteAgentLoop(
          channel: syncChannel,
          config: config,
          sessionId: sessionId,
          requestApproval: handleRequestApproval,
          onTextDelta: handleTextDelta,
          onAssistantMessage: handleAssistantMessage,
          onToolResultMessage: handleToolResultMessage,
        );
      } else {
        // Run the agent loop locally
        // Get conversation history
        final dbMessages = await _messageDao.getMessagesBySession(sessionId);
        final conversation = _buildConversationHistory(dbMessages);

        result = await runAgentLoop(
          llmStream: (conv, tools) =>
              _llmService.streamChat(conv, tools: tools),
          tools: shellTools,
          conversation: conversation,
          getConversation: () async {
            // Rebuild conversation from database each iteration (single source of truth)
            final dbMessages =
                await _messageDao.getMessagesBySession(sessionId);
            return _buildConversationHistory(dbMessages);
          },
          requestApproval: handleRequestApproval,
          executeToolCall: (toolCall) async {
            // Execute and return result as JSON string
            final result = await _executeToolCall(toolCall);
            return jsonEncode(result);
          },
          onTextDelta: handleTextDelta,
          onAssistantMessage: handleAssistantMessage,
          onToolResultMessage: handleToolResultMessage,
        );
      }

      // Handle result
      switch (result) {
        case AgentLoopCompleted():
          developer.log('✅ Agent loop completed', name: 'ChatController');
        case AgentLoopCancelled():
          developer.log(
            '🚨 User cancelled tool execution',
            name: 'ChatController',
          );
        case AgentLoopError(message: final errorMsg):
          final errorMessage = 'Sorry, I encountered an error: $errorMsg';
          final redactedError = await _secretRedactor.redact(errorMessage);
          await _messageDao.insertMessageWithId(
            sessionId: sessionId,
            userId: _kAiUserId,
            userName: _kAiUserName,
            content: redactedError,
          );
          state = state.copyWith(isLoading: false, error: errorMsg);
          return;
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      final errorMessage = 'Sorry, I encountered an error: $e';
      final redactedError = await _secretRedactor.redact(errorMessage);
      await _messageDao.insertMessageWithId(
        sessionId: sessionId,
        userId: _kAiUserId,
        userName: _kAiUserName,
        content: redactedError,
      );
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Execute a single tool call and return result as Map
  Future<Map<String, dynamic>> _executeToolCall(ToolCall toolCall) async {
    final argumentsJson = toolCall.function.arguments;
    final params = argumentsJson.isNotEmpty
        ? Map<String, dynamic>.from(jsonDecode(argumentsJson))
        : <String, dynamic>{};

    final result = await _executeAction(toolCall.function.name, params);
    return result['data'] as Map<String, dynamic>;
  }

  /// Execute a single action (shell command or fetch)
  Future<Map<String, dynamic>> _executeAction(
    String actionName,
    Map<String, dynamic> params,
  ) async {
    if (actionName == kExecuteShellCommand) {
      final command = params['command'] as String;
      final sudoRequired = params['sudo_required'] as bool? ?? false;

      Map<String, dynamic> result;

      try {
        if (sudoRequired) {
          result = await _shellService.executeWithSudo(
            command: command,
            sudoPasswordSecretId: _sshSettings?.sudoPasswordSecretId ??
                _sshSettings?.passwordSecretId,
          );
        } else {
          result = await _shellService.executeCommand(command);
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
      }

      return {
        'success': (result['exitCode'] as int? ?? -1) == 0,
        'data': result,
        'error': result['stderr'] as String?,
      };
    }

    if (actionName == kFetch) {
      final url = params['url'] as String;
      final method = (params['method'] as String?)?.toUpperCase() ?? 'GET';
      final headers = params['headers'] as Map<String, dynamic>?;
      final body = params['body'] as String?;
      final timeoutSeconds = params['timeout'] as int? ?? 30;

      try {
        final dio = Dio();
        final response = await dio
            .request(
              url,
              data: body,
              options: Options(
                method: method,
                headers: headers,
                responseType: ResponseType.plain,
                validateStatus: (status) => true, // Accept all status codes
              ),
            )
            .timeout(Duration(seconds: timeoutSeconds));

        final isSuccess = response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300;

        return {
          'success': isSuccess,
          'data': {
            'statusCode': response.statusCode ?? 0,
            'headers': response.headers.map,
            'body': response.data?.toString() ?? '',
            'url': url,
            'method': method,
          },
          'error': isSuccess ? null : 'HTTP ${response.statusCode}',
        };
      } catch (e) {
        return {
          'success': false,
          'data': {
            'statusCode': 0,
            'headers': {},
            'body': '',
            'url': url,
            'method': method,
          },
          'error': e.toString(),
        };
      }
    }

    throw Exception('Unknown action: $actionName');
  }

  /// Edit a message and resend from that point
  /// Updates the message content, deletes all messages after it, then resends
  Future<void> editMessage({
    required String messageId,
    required String newContent,
    required String sessionId,
    required Future<List<ToolAction>?> Function(List<ToolAction>)
        requestApproval,
    MultiplexedWebSocketChannel? syncChannel,
  }) async {
    developer.log('✏️ Editing message: $messageId', name: 'ChatController');

    // Get the message to find its timestamp
    final message = await _messageDao.getMessage(messageId);
    if (message == null) {
      developer.log('❌ Message not found: $messageId', name: 'ChatController');
      return;
    }

    // Update the message content
    await _messageDao.updateMessageContent(
      messageId: messageId,
      newContent: newContent,
    );

    developer.log('💾 Updated message content', name: 'ChatController');

    // Delete all messages AFTER this one (keep the edited message)
    final deletedCount = await _messageDao.deleteMessagesAfter(
      sessionId: sessionId,
      afterTimestamp: message.timestamp,
    );

    developer.log(
      '🗑️ Deleted $deletedCount messages after edit, now resending',
      name: 'ChatController',
    );

    // Resend from the edited message
    await sendMessage(
      content: null, // Use existing conversation (now with edited message)
      sessionId: sessionId,
      requestApproval: requestApproval,
      syncChannel: syncChannel,
    );
  }

  /// Resend a message: delete all messages after it, then resend from that point
  Future<void> resendMessage({
    required String messageId,
    required String sessionId,
    required Future<List<ToolAction>?> Function(List<ToolAction>)
        requestApproval,
    MultiplexedWebSocketChannel? syncChannel,
  }) async {
    developer.log(
      '🔄 Resending from message: $messageId',
      name: 'ChatController',
    );

    // Get the message to find its timestamp
    final message = await _messageDao.getMessage(messageId);
    if (message == null) {
      developer.log('❌ Message not found: $messageId', name: 'ChatController');
      return;
    }

    // Delete all messages AFTER this one (keep the message itself)
    final deletedCount = await _messageDao.deleteMessagesAfter(
      sessionId: sessionId,
      afterTimestamp: message.timestamp,
    );

    developer.log(
      '🗑️ Deleted $deletedCount messages after target, now resending',
      name: 'ChatController',
    );

    // Resend - conversation will include the message we're resending from
    await sendMessage(
      content: null, // Use existing conversation
      sessionId: sessionId,
      requestApproval: requestApproval,
      syncChannel: syncChannel,
    );
  }

  /// Branch the session by creating a copy up to a specific message
  /// Returns the new session ID
  Future<String> branchSession({
    required String messageId,
    required String sessionId,
  }) async {
    developer.log(
      '🌿 Branching session at message: $messageId',
      name: 'ChatController',
    );

    final newSessionId = await _sessionDao.branchSession(
      sessionId: sessionId,
      upToMessageId: messageId,
    );

    developer.log(
      '✅ Created new session: $newSessionId',
      name: 'ChatController',
    );

    return newSessionId;
  }

  /// Start streaming for a message
  void startStreaming(String messageId) {
    state = state.copyWith(streamingMessageId: messageId, streamingText: '');
  }

  /// Update streaming text for a message
  void updateStreamingText(String text) {
    state = state.copyWith(streamingText: text);
  }

  /// Stop streaming
  void stopStreaming() {
    state = state.copyWith(streamingMessageId: null, streamingText: '');
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}
