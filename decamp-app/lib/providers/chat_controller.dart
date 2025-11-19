import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_dart/llm_dart.dart';
import 'package:drift/drift.dart';
import '../extensions/chat_message_extensions.dart';
import '../models/chat_state.dart';
import '../models/ssh_settings.dart';
import '../services/llm_service.dart';
import '../services/shell_service.dart';
import '../services/shell_tools_provider.dart';
import '../providers/database_provider.dart';
import '../providers/project_provider.dart';
import '../providers/ssh_settings_provider.dart';
import '../database/daos/message_dao.dart';
import '../database/daos/session_dao.dart';
import '../database/database.dart';
import '../components/multi_command_approval_overlay.dart';

/// Controller for chat session state management
/// Handles all business logic for chat interactions, tool execution, and message syncing
/// Directly calls DAOs and services without unnecessary repository layer
class ChatController extends StateNotifier<ChatState> {
  final MessageDao _messageDao;
  final SessionDao _sessionDao;
  final LlmService _llmService;
  final ShellService _shellService;
  final SshSettings? _sshSettings;
  final String? sessionId;

  ChatController({
    required MessageDao messageDao,
    required SessionDao sessionDao,
    required LlmService llmService,
    required ShellService shellService,
    SshSettings? sshSettings,
    this.sessionId,
  }) : _messageDao = messageDao,
       _sessionDao = sessionDao,
       _llmService = llmService,
       _shellService = shellService,
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
  }) async {
    // Save user's message to database
    await _messageDao.insertMessageWithId(
      sessionId: sessionId,
      userId: 'user',
      userName: 'You',
      content: content,
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
        await _messageDao.insertMessageWithId(
          sessionId: sessionId,
          userId: 'ai',
          userName: 'Ops Agent',
          content: errorMessage,
        );

        state = state.copyWith(isLoading: false, error: result.error);
        return;
      }

      // Handle tool calls by showing approval overlay
      if (result.hasToolCalls && result.conversationState != null) {
        // Save conversation state for later continuation
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

        state = state.copyWith(
          pendingActions: actions,
          conversationForToolCalls: result.conversationState,
          pendingToolCalls: result.toolCalls,
          assistantTextBeforeTools: result.textResponse,
          isLoading: false,
        );

        return;
      }

      // Save text response if any
      if (result.hasTextResponse) {
        await _messageDao.insertMessageWithId(
          id: aiMessageId,
          sessionId: sessionId,
          userId: 'ai',
          userName: 'Ops Agent',
          content: result.textResponse!,
        );
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      final errorMessage = 'Sorry, I encountered an error: $e';
      await _messageDao.insertMessageWithId(
        sessionId: sessionId,
        userId: 'ai',
        userName: 'Ops Agent',
        content: errorMessage,
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
  Future<void> executeActions({
    required List<CommandAction> selectedActions,
    required String sessionId,
  }) async {
    // First, save the assistant's message with tool calls to preserve conversation state
    final pendingCalls = state.pendingToolCalls;
    final assistantText = state.assistantTextBeforeTools;

    if (pendingCalls != null && pendingCalls.isNotEmpty) {
      // Generate message ID upfront
      final assistantMessageId = _messageDao.generateMessageId();

      // Create the ChatMessage with tool calls
      final chatMessage = ChatMessage.toolUse(
        toolCalls: pendingCalls,
        content: assistantText ?? '',
      );

      developer.log(
        '💾 Saving assistant message with ${pendingCalls.length} tool calls',
        name: 'ChatController',
      );
      developer.log(
        '  Tool calls: ${pendingCalls.map((tc) => tc.function.name).join(", ")}',
        name: 'ChatController',
      );

      // Convert to companion and insert
      final companion = chatMessage.toMessageCompanion(
        sessionId: sessionId,
        id: assistantMessageId,
      );

      await _messageDao.insertMessage(companion);
    }

    // Clear the approval overlay and set execution state
    state = state.copyWith(
      pendingActions: null,
      executionProgress: ExecutionProgress(
        currentCommand: 0,
        totalCommands: selectedActions.length,
        commandName: '',
      ),
    );

    try {
      // Execute actions sequentially with progress updates
      for (var i = 0; i < selectedActions.length; i++) {
        final action = selectedActions[i];
        final command = action.command;

        // Update progress
        state = state.copyWith(
          executionProgress: ExecutionProgress(
            currentCommand: i + 1,
            totalCommands: selectedActions.length,
            commandName: command,
          ),
        );
      }

      // Clear execution progress, show loading for LLM response
      state = state.copyWith(executionProgress: null, isLoading: true);

      // Get the tool calls that match the selected actions
      final pendingCalls = state.pendingToolCalls;
      if (pendingCalls == null) {
        throw Exception('No pending tool calls in state');
      }

      final selectedToolCalls = selectedActions.map((action) {
        // Find matching tool call by ID
        final matchingToolCall = pendingCalls.firstWhere(
          (tc) => tc.id == action.id,
          orElse: () => throw Exception('Tool call not found: ${action.id}'),
        );
        return matchingToolCall;
      }).toList();

      // Execute tool calls
      final result = await _executeToolCalls(
        toolCalls: selectedToolCalls,
        conversationState: state.conversationForToolCalls!,
      );

      // Save ONE consolidated tool result message with ALL results
      // Anthropic API requires all tool results in a single message immediately after tool_use
      final allResultToolCalls = result.toolCalls.map((toolCall) {
        final toolResult = result.toolResults[toolCall.id] ?? 'No result';

        return ToolCall(
          id: toolCall.id,
          callType: toolCall.callType,
          function: FunctionCall(
            name: toolCall.function.name,
            arguments: toolResult,
          ),
        );
      }).toList();

      // Combine all tool results into one content string
      final combinedContent = result.toolCalls
          .map((toolCall) {
            return result.toolResults[toolCall.id] ?? 'No result';
          })
          .join('\n---\n');

      final chatMessage = ChatMessage.toolResult(
        results: allResultToolCalls, // ALL results in one message
        content: combinedContent,
      );

      developer.log(
        '💾 Saving consolidated tool results for ${result.toolCalls.length} tools',
        name: 'ChatController',
      );

      // Save ONE message with all results
      final companion = chatMessage.toMessageCompanion(sessionId: sessionId);
      await _messageDao.insertMessage(companion);

      // Handle LLM's follow-up response after tool execution
      if (result.followUpResult != null) {
        final followUp = result.followUpResult!;

        // If LLM wants to make more tool calls, show approval overlay
        if (followUp.hasToolCalls) {
          final actions = followUp.toolCalls!.map((tc) {
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

          state = state.copyWith(
            pendingActions: actions,
            conversationForToolCalls: followUp.conversationState,
            pendingToolCalls: followUp.toolCalls,
            assistantTextBeforeTools: followUp.textResponse,
            isLoading: false,
          );

          return;
        }

        // Save follow-up text response (LLM explaining results, asking follow-up, etc.)
        if (followUp.hasTextResponse) {
          await _messageDao.insertMessageWithId(
            sessionId: sessionId,
            userId: 'ai',
            userName: 'Ops Agent',
            content: followUp.textResponse!,
          );
        }
      }

      // Clear conversation state and loading
      state = state.copyWith(
        conversationForToolCalls: null,
        pendingToolCalls: null,
        assistantTextBeforeTools: null,
        isLoading: false,
      );
    } catch (e) {
      final errorMessage = '❌ Error executing commands: $e';
      await _messageDao.insertMessageWithId(
        sessionId: sessionId,
        userId: 'ai',
        userName: 'Ops Agent',
        content: errorMessage,
      );

      // Clear all state on error
      state = state.copyWith(
        conversationForToolCalls: null,
        pendingToolCalls: null,
        assistantTextBeforeTools: null,
        executionProgress: null,
        isLoading: false,
        error: e.toString(),
      );
    }
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
    if (actionName == 'execute_shell_command') {
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

    throw Exception('Unknown action: $actionName');
  }

  /// Cancel pending actions
  void cancelActions() {
    state = state.copyWith(
      pendingActions: null,
      conversationForToolCalls: null,
      pendingToolCalls: null,
      assistantTextBeforeTools: null,
    );
  }

  /// Edit a message and resend from that point
  /// Deletes all messages after the edited message and sends it to AI
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

    // Get updated message history
    final dbMessages = await _messageDao.getMessagesBySession(sessionId);

    // Check if this is the only message
    final isFirstMessage = dbMessages.length == 1;

    // Send the edited message to AI
    await sendMessage(
      content: newContent,
      sessionId: sessionId,
      dbMessages: dbMessages,
      isFirstMessage: isFirstMessage,
    );
  }

  /// Resend a message without editing
  /// Deletes the message and all messages after it, then sends it again
  Future<void> resendMessage({
    required String messageId,
    required String sessionId,
  }) async {
    developer.log('🔄 Resending message: $messageId', name: 'ChatController');

    // Get the message
    final message = await _messageDao.getMessage(messageId);
    if (message == null) {
      developer.log('❌ Message not found: $messageId', name: 'ChatController');
      return;
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

    // Get updated message history
    final dbMessages = await _messageDao.getMessagesBySession(sessionId);

    // Check if this will be the first message
    final isFirstMessage = dbMessages.isEmpty;

    // Send the message again
    await sendMessage(
      content: content,
      sessionId: sessionId,
      dbMessages: dbMessages,
      isFirstMessage: isFirstMessage,
    );
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

      return ChatController(
        messageDao: ref.watch(databaseProvider).messageDao,
        sessionDao: ref.watch(databaseProvider).sessionDao,
        llmService: ref.watch(llmServiceProvider),
        shellService: ref.watch(shellServiceProvider(projectId)),
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
