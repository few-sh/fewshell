import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_dart/llm_dart.dart';
import 'package:drift/drift.dart';
import '../extensions/chat_message_extensions.dart';
import '../models/chat_state.dart';
import '../models/ssh_settings.dart';
import '../services/llm_service.dart';
import '../services/shell_service.dart';
import '../services/shell_tools_provider.dart'
    show shellTools, kExecuteShellCommand, kFetch;
import '../providers/database_provider.dart';
import '../providers/project_provider.dart';
import '../providers/ssh_settings_provider.dart';
import '../providers/secret_provider.dart';
import '../database/daos/message_dao.dart';
import '../database/daos/session_dao.dart';
import '../database/database.dart';
import '../components/multi_command_approval_overlay.dart';
import '../utils/secret_redactor.dart';

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
  }) : _messageDao = messageDao,
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

  /// Send a message to the AI
  /// Handles saving to database, getting AI response, and managing tool calls
  ///
  /// Streaming is managed internally through ChatState:
  /// - startStreaming: Sets streamingMessageId in state
  /// - updateStreamingText: Updates streamingText in state
  /// - stopStreaming: Clears streaming state
  Future<void> sendMessage({
    required String content,
    required String sessionId,
    required List<dynamic> dbMessages,
    required bool isFirstMessage,
    required Future<List<CommandAction>?> Function(List<CommandAction>)
    requestApproval,
  }) async {
    // Redact secrets from user's message before saving to database
    final redactedContent = await _secretRedactor.redact(content);

    // Save user's message to database
    await _messageDao.insertMessageWithId(
      sessionId: sessionId,
      userId: 'user',
      userName: 'You',
      content: redactedContent,
    );

    // Update session description if first message
    if (isFirstMessage) {
      final description = content.length > 495
          ? '${content.substring(0, 495)}...'
          : content;

      await _sessionDao.updateSession(
        SessionEntityCompanion(
          id: Value(sessionId),
          description: Value(description),
        ),
      );
    }

    // Set loading state
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Check if LLM is configured
      final isConfigured = await _llmService.isConfigured();

      if (!isConfigured) {
        const configMessage =
            "⚠️ No LLM configured. Please go to Settings → AI Models to configure an LLM provider.";

        await _messageDao.insertMessageWithId(
          sessionId: sessionId,
          userId: 'ai',
          userName: 'Ops Agent',
          content: configMessage,
        );

        state = state.copyWith(isLoading: false);
        return;
      }

      // Generate message ID upfront for consistent tracking across streaming and DB
      final aiMessageId = _messageDao.generateMessageId();

      // Send message to AI with streaming support
      final result = await _sendMessageToAI(
        messageContent: content,
        dbMessages: dbMessages,
        messageId: aiMessageId,
      );

      // Handle error
      if (result.hasError) {
        final errorMessage = 'Sorry, I encountered an error: ${result.error}';
        final redactedError = await _secretRedactor.redact(errorMessage);
        await _messageDao.insertMessageWithId(
          sessionId: sessionId,
          userId: 'ai',
          userName: 'Ops Agent',
          content: redactedError,
        );

        state = state.copyWith(isLoading: false, error: result.error);
        return;
      }

      // Handle tool calls by requesting approval
      if (result.hasToolCalls && result.conversationState != null) {
        // Convert tool calls to actions
        final actions = result.toolCalls!.map((tc) {
          // Parse params from tool call
          final argumentsJson = tc.function.arguments;
          final params = argumentsJson.isNotEmpty
              ? Map<String, dynamic>.from(jsonDecode(argumentsJson))
              : <String, dynamic>{};

          return CommandAction(
            id: tc.id,
            actionName: tc.function.name,
            params: params,
          );
        }).toList();

        // Directly await user approval - no state updates!
        final selectedActions = await requestApproval(actions);

        // If user cancelled, we're done
        if (selectedActions == null) {
          developer.log(
            '🚨 User cancelled tool execution',
            name: 'ChatController',
          );
          state = state.copyWith(isLoading: false);
          return;
        }

        // User approved - execute the selected tools
        developer.log(
          '✅ User approved ${selectedActions.length} tool calls',
          name: 'ChatController',
        );

        // Execute tools and handle follow-up (will be implemented in step 4)
        // TODO: Call _executeToolCallsAndContinue here
        state = state.copyWith(isLoading: false);
        return;
      }

      // Save text response if any
      if (result.hasTextResponse) {
        final redactedResponse = await _secretRedactor.redact(
          result.textResponse!,
        );
        await _messageDao.insertMessageWithId(
          id: aiMessageId,
          sessionId: sessionId,
          userId: 'ai',
          userName: 'Ops Agent',
          content: redactedResponse,
        );
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      final errorMessage = 'Sorry, I encountered an error: $e';
      final redactedError = await _secretRedactor.redact(errorMessage);
      await _messageDao.insertMessageWithId(
        sessionId: sessionId,
        userId: 'ai',
        userName: 'Ops Agent',
        content: redactedError,
      );

      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Send a message to the AI and get response
  /// Handles streaming, tool calls, and conversation state
  Future<_MessageResult> _sendMessageToAI({
    required String messageContent,
    required List<dynamic> dbMessages,
    required String messageId,
  }) async {
    try {
      // Build conversation from database messages
      final conversation = _buildConversationHistory(dbMessages);

      // Add the new user message
      conversation.add(ChatMessage.user(messageContent));

      developer.log(
        '📤 Sending to LLM with ${conversation.length} messages in conversation',
        name: 'ChatController',
      );

      // Log conversation summary for debugging
      for (var i = 0; i < conversation.length; i++) {
        final msg = conversation[i];
        final messageType = msg.messageType;
        if (messageType is ToolUseMessage) {
          developer.log(
            '  [$i] ${msg.role.name}: Tool calls (${messageType.toolCalls.length})',
            name: 'ChatController',
          );
        } else if (messageType is ToolResultMessage) {
          developer.log(
            '  [$i] ${msg.role.name}: Tool results (${messageType.results.length})',
            name: 'ChatController',
          );
        } else {
          final preview = msg.content.length > 50
              ? '${msg.content.substring(0, 50)}...'
              : msg.content;
          developer.log(
            '  [$i] ${msg.role.name}: $preview',
            name: 'ChatController',
          );
        }
      }

      // Get shell tools
      final tools = shellTools;

      // Stream from service
      final buffer = StringBuffer();
      final collectedToolCalls = <ToolCall>[];
      var hasStartedStreaming = false;

      await for (final event in _llmService.streamChat(
        conversation,
        tools: tools,
      )) {
        switch (event) {
          case TextDeltaEvent(delta: final delta):
            buffer.write(delta);
            if (!hasStartedStreaming) {
              startStreaming(messageId);
              hasStartedStreaming = true;
            }
            updateStreamingText(buffer.toString());

          case ToolCallDeltaEvent(toolCall: final toolCall):
            collectedToolCalls.add(toolCall);

          case CompletionEvent():
            break;

          case ErrorEvent(error: final error):
            if (hasStartedStreaming) stopStreaming();
            return _MessageResult(error: error.message);

          case ThinkingDeltaEvent():
            break;
        }
      }

      if (hasStartedStreaming) stopStreaming();

      // Build result
      if (collectedToolCalls.isNotEmpty) {
        // Add assistant's tool use message to conversation
        conversation.add(
          ChatMessage.toolUse(
            toolCalls: collectedToolCalls,
            content: buffer.toString(),
          ),
        );

        return _MessageResult(
          textResponse: buffer.toString(),
          toolCalls: collectedToolCalls,
          conversationState: conversation,
        );
      }

      return _MessageResult(textResponse: buffer.toString());
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error sending message to AI: $e',
        name: 'ChatController',
        error: e,
        stackTrace: stackTrace,
      );

      return _MessageResult(error: e.toString());
    }
  }

  /// Execute multiple approved actions
  /// TODO: This method will be completely refactored in step 4 to use direct parameters
  Future<void> executeActions({
    required List<CommandAction> selectedActions,
    required String sessionId,
  }) async {
    // Temporary stub - this will be replaced in step 4
    // For now, just throw to prevent calls until refactored
    state = state.copyWith(isLoading: false, pendingActions: null);
    throw UnimplementedError(
      'executeActions is being refactored to use approval handler pattern. '
      'This will be implemented in step 4.',
    );
  }

  /// Execute tool calls and handle follow-up responses
  Future<_ToolExecutionResult> _executeToolCalls({
    required List<ToolCall> toolCalls,
    required List<ChatMessage> conversationState,
  }) async {
    final toolResults = <String, String>{};
    final chatMessages = <String>[];

    try {
      // Execute each tool call
      for (var i = 0; i < toolCalls.length; i++) {
        final toolCall = toolCalls[i];

        // Parse params from tool call
        final argumentsJson = toolCall.function.arguments;
        final params = argumentsJson.isNotEmpty
            ? Map<String, dynamic>.from(jsonDecode(argumentsJson))
            : <String, dynamic>{};

        final command = params['command'] as String? ?? 'unknown';

        // Execute the action directly
        final result = await _executeAction(toolCall.function.name, params);

        // Build result message
        final resultMessage = _formatExecutionResult(
          command,
          result['success'] as bool,
          result['data'],
          result['error'],
        );

        chatMessages.add(resultMessage);

        // Map result for LLM
        toolResults[toolCall.id] = jsonEncode(result['data']);
      }

      // Get tools for potential follow-up
      final tools = shellTools;

      // Create a mutable copy of conversation and add tool results
      // (conversationState may be unmodifiable)
      final conversationWithResults = List<ChatMessage>.from(conversationState);

      // Consolidate ALL tool results into a single message
      // Anthropic API requires all tool results in one message immediately after tool_use
      final allResults = toolCalls.map((toolCall) {
        final result = toolResults[toolCall.id] ?? 'No result';
        return ToolCall(
          id: toolCall.id,
          callType: toolCall.callType,
          function: FunctionCall(
            name: toolCall.function.name,
            arguments: result,
          ),
        );
      }).toList();

      final combinedContent = toolCalls
          .map((toolCall) {
            return toolResults[toolCall.id] ?? 'No result';
          })
          .join('\n---\n');

      conversationWithResults.add(
        ChatMessage.toolResult(
          results: allResults, // ALL results in one message
          content: combinedContent,
        ),
      );

      developer.log(
        '📋 Conversation state before follow-up (${conversationWithResults.length} messages):',
        name: 'ChatController',
      );
      for (var i = 0; i < conversationWithResults.length; i++) {
        final msg = conversationWithResults[i];
        final messageType = msg.messageType;
        if (messageType is ToolUseMessage) {
          developer.log(
            '  [$i] ${msg.role.name}: Tool calls',
            name: 'ChatController',
          );
        } else if (messageType is ToolResultMessage) {
          developer.log(
            '  [$i] ${msg.role.name}: Tool results',
            name: 'ChatController',
          );
        } else {
          final preview = msg.content.length > 50
              ? '${msg.content.substring(0, 50)}...'
              : msg.content;
          developer.log(
            '  [$i] ${msg.role.name}: $preview',
            name: 'ChatController',
          );
        }
      }

      // Continue conversation with tool results
      final followUpResult = await _continueWithToolResults(
        conversationState: conversationWithResults,
        tools: tools,
      );

      return _ToolExecutionResult(
        toolResults: toolResults,
        chatMessages: chatMessages,
        toolCalls: toolCalls,
        followUpResult: followUpResult,
      );
    } catch (e) {
      return _ToolExecutionResult(
        toolResults: toolResults,
        chatMessages: chatMessages,
        toolCalls: toolCalls,
        error: e.toString(),
      );
    }
  }

  /// Continue conversation with tool results
  Future<_MessageResult?> _continueWithToolResults({
    required List<ChatMessage> conversationState,
    required List<Tool> tools,
  }) async {
    try {
      final buffer = StringBuffer();
      final followUpToolCalls = <ToolCall>[];

      await for (final event in _llmService.streamChat(
        conversationState,
        tools: tools,
      )) {
        switch (event) {
          case TextDeltaEvent(delta: final delta):
            buffer.write(delta);

          case ToolCallDeltaEvent(toolCall: final toolCall):
            followUpToolCalls.add(toolCall);

          case CompletionEvent():
            break;

          case ErrorEvent(error: final error):
            return _MessageResult(error: error.message);

          case ThinkingDeltaEvent():
            break;
        }
      }

      // Return result if we have follow-up tool calls or text
      if (followUpToolCalls.isNotEmpty) {
        // Add assistant's tool use message to conversation
        conversationState.add(
          ChatMessage.toolUse(
            toolCalls: followUpToolCalls,
            content: buffer.toString(),
          ),
        );

        return _MessageResult(
          textResponse: buffer.toString(),
          toolCalls: followUpToolCalls,
          conversationState: conversationState,
        );
      }

      if (buffer.isNotEmpty) {
        return _MessageResult(textResponse: buffer.toString());
      }

      return null;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error continuing with tool results: $e',
        name: 'ChatController',
        error: e,
        stackTrace: stackTrace,
      );

      return _MessageResult(error: e.toString());
    }
  }

  /// Format execution result as a chat message
  String _formatExecutionResult(
    String command,
    bool success,
    dynamic data,
    dynamic error,
  ) {
    final buffer = StringBuffer();

    if (success) {
      buffer.writeln('✅ **Executed:**');
      buffer.writeln('```');
      buffer.writeln(command);
      buffer.writeln('```');
      buffer.writeln();

      // Print stdout if available
      final stdout = data?['stdout']?.toString().trim() ?? '';
      if (stdout.isNotEmpty) {
        buffer.writeln('**Result:**');
        buffer.writeln('```');
        buffer.writeln(stdout);
        buffer.writeln('```');
        buffer.writeln();
      }

      // Print stderr if available
      final stderr = data?['stderr']?.toString().trim() ?? '';
      if (stderr.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('**⚠️ Warning (stderr):**');
        buffer.writeln('```');
        buffer.writeln(stderr);
        buffer.writeln('```');
      }

      // Print exit code only if non-zero
      final exitCode = data?['exitCode'] as int?;
      if (exitCode != null && exitCode != 0) {
        buffer.writeln();
        buffer.writeln('**Exit Code:** $exitCode');
      }
    } else {
      buffer.writeln('❌ **Failed:** `$command`');
      buffer.writeln();
      buffer.writeln('**Error:**');
      buffer.writeln('```');
      buffer.writeln(error?.toString() ?? 'Unknown error');
      buffer.writeln('```');
    }

    return buffer.toString().trim();
  }

  /// Execute a single action (shell command)
  Future<Map<String, dynamic>> _executeAction(
    String actionName,
    Map<String, dynamic> params,
  ) async {
    if (actionName == kExecuteShellCommand) {
      final command = params['command'] as String;
      final sudoRequired = params['sudo_required'] as bool? ?? false;

      final Map<String, dynamic> result;

      if (sudoRequired) {
        result = await _shellService.executeWithSudo(
          command: command,
          sudoPasswordSecretId:
              _sshSettings?.sudoPasswordSecretId ??
              _sshSettings?.passwordSecretId,
        );
      } else {
        result = await _shellService.executeCommand(command);
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

        final isSuccess =
            response.statusCode != null &&
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

  /// Cancel pending actions
  void cancelActions() {
    state = state.copyWith(pendingActions: null);
  }

  /// Edit a message
  /// Deletes all messages after the edited message and updates the message content
  /// UI should call sendMessage separately if resend is desired
  Future<void> editMessage({
    required String messageId,
    required String newContent,
    required String sessionId,
  }) async {
    developer.log('✏️ Editing message: $messageId', name: 'ChatController');

    // Get the message to find its timestamp
    final message = await _messageDao.getMessage(messageId);
    if (message == null) {
      developer.log('❌ Message not found: $messageId', name: 'ChatController');
      return;
    }

    // Delete all messages after this one
    final deletedCount = await _messageDao.deleteMessagesAfter(
      sessionId: sessionId,
      afterTimestamp: message.timestamp,
    );

    developer.log(
      '🗑️ Deleted $deletedCount messages after edited message',
      name: 'ChatController',
    );

    // Update the message content
    await _messageDao.updateMessageContent(
      messageId: messageId,
      newContent: newContent,
    );

    developer.log('💾 Updated message content', name: 'ChatController');
  }

  /// Delete a message and all messages after it
  /// Returns the message content so UI can resend it
  Future<String?> resendMessage({
    required String messageId,
    required String sessionId,
  }) async {
    developer.log(
      '🔄 Preparing to resend message: $messageId',
      name: 'ChatController',
    );

    // Get the message
    final message = await _messageDao.getMessage(messageId);
    if (message == null) {
      developer.log('❌ Message not found: $messageId', name: 'ChatController');
      return null;
    }

    final content = message.content;

    // Delete all messages after this one (including this one)
    final deletedCount = await _messageDao.deleteMessagesAfter(
      sessionId: sessionId,
      afterTimestamp: message.timestamp.subtract(
        const Duration(milliseconds: 1),
      ),
    );

    developer.log(
      '🗑️ Deleted $deletedCount messages (including the message to resend)',
      name: 'ChatController',
    );

    return content;
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

/// Provider for ChatController
/// Uses family provider to scope controller to specific session
final chatControllerProvider =
    StateNotifierProvider.family<ChatController, ChatState, String?>((
      ref,
      sessionId,
    ) {
      // Get current project to access shell service and SSH settings
      final currentProject = ref.watch(currentProjectProvider);
      final projectId = currentProject?.id;

      final sshSettings = projectId != null
          ? ref.watch(projectSshSettingsProvider(projectId))
          : null;

      // Create secret redactor for this project
      final keychain = ref.watch(keychainServiceProvider);
      final secretRedactor = SecretRedactor(keychain, projectId);

      return ChatController(
        messageDao: ref.watch(databaseProvider).messageDao,
        sessionDao: ref.watch(databaseProvider).sessionDao,
        llmService: ref.watch(llmServiceProvider),
        shellService: ref.watch(shellServiceProvider(projectId)),
        secretRedactor: secretRedactor,
        sshSettings: sshSettings,
        sessionId: sessionId,
      );
    });

// Internal helper classes

/// Result of sending a message to the AI
class _MessageResult {
  final String? textResponse;
  final List<ToolCall>? toolCalls;
  final List<ChatMessage>? conversationState;
  final String? error;

  const _MessageResult({
    this.textResponse,
    this.toolCalls,
    this.conversationState,
    this.error,
  });

  bool get hasError => error != null;
  bool get hasToolCalls => toolCalls != null && toolCalls!.isNotEmpty;
  bool get hasTextResponse => textResponse != null && textResponse!.isNotEmpty;
}

/// Result of executing tool calls
class _ToolExecutionResult {
  final Map<String, String> toolResults;
  final List<String> chatMessages;
  final List<ToolCall> toolCalls;
  final _MessageResult? followUpResult;
  final String? error;

  const _ToolExecutionResult({
    required this.toolResults,
    required this.chatMessages,
    required this.toolCalls,
    this.followUpResult,
    this.error,
  });

  bool get hasError => error != null;
  bool get hasFollowUp =>
      followUpResult != null && followUpResult!.hasToolCalls;
}
