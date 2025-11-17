import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_dart/llm_dart.dart' as llm;
import 'package:drift/drift.dart';
import '../extensions/chat_message_extensions.dart';
import '../models/chat_state.dart';
import '../services/llm_service.dart';
import '../services/shell_tools_provider.dart';
import '../providers/database_provider.dart';
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
  final String? sessionId;

  ChatController({
    required MessageDao messageDao,
    required SessionDao sessionDao,
    required LlmService llmService,
    this.sessionId,
  })  : _messageDao = messageDao,
        _sessionDao = sessionDao,
        _llmService = llmService,
        super(const ChatState());

  /// Reset state when session changes (called by provider when session changes)
  void resetForNewSession() {
    state = const ChatState();
  }

  /// Build conversation history from database messages
  /// Reconstructs proper ChatMessage objects including tool use and tool results
  List<llm.ChatMessage> _buildConversationHistory(List<dynamic> dbMessages) {
    final conversation = <llm.ChatMessage>[];

    for (final msg in dbMessages) {
      final userId = msg.userId as String;
      final content = msg.content as String;
      final metadata = msg.metadata as String?;

      // Try to reconstruct from metadata first if it exists
      if (metadata != null && metadata.isNotEmpty) {
        try {
          final json = jsonDecode(metadata) as Map<String, dynamic>;
          final chatMessage = ChatMessageStorage.fromStorageJson(json);
          conversation.add(chatMessage);

          developer.log(
            '📦 Restored ${json['messageType']} message from metadata',
            name: 'ChatController',
          );
          continue;
        } catch (e) {
          developer.log(
            '⚠️ Failed to deserialize ChatMessage from metadata: $e',
            name: 'ChatController',
          );
          // Fall through to simple text conversion
        }
      }

      // Fallback: create simple text message based on userId
      if (userId == 'user') {
        conversation.add(llm.ChatMessage.user(content));
      } else if (userId == 'ai' || userId == 'assistant') {
        conversation.add(llm.ChatMessage.assistant(content));
      } else if (userId == 'tool') {
        // Tool messages without metadata - skip them as they can't be properly reconstructed
        developer.log(
          '⚠️ Tool message without metadata, skipping',
          name: 'ChatController',
        );
      }
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
    developer.log('🎯 sendMessage called', name: 'ChatController');

    // Save user's message to database
    final userMessageId = await _messageDao.insertMessageWithId(
      sessionId: sessionId,
      userId: 'user',
      userName: 'You',
      content: content,
    );

    developer.log(
      'User message saved with ID: $userMessageId',
      name: 'ChatController',
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

      developer.log(
        'Updated session description: $description',
        name: 'ChatController',
      );
    }

    // Set loading state
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Check if LLM is configured
      final isConfigured = await _llmService.isConfigured();

      if (!isConfigured) {
        developer.log('❌ LLM not configured', name: 'ChatController');

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
        developer.log('❌ Error: ${result.error}', name: 'ChatController');

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
        developer.log(
          '🔧 Showing approval overlay for ${result.toolCalls!.length} tool calls',
          name: 'ChatController',
        );

        // Save conversation state for later continuation
        final actions = result.toolCalls!.map((tc) {
          return CommandAction(
            id: tc.id,
            actionName: tc.name,
            params: tc.params,
          );
        }).toList();

        state = state.copyWith(
          pendingActions: actions,
          conversationForToolCalls: result.conversationState,
          pendingToolCalls: result.toolCalls!.map((tc) => tc.toolCall).toList(),
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
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error in sendMessage: $e',
        name: 'ChatController',
        error: e,
        stackTrace: stackTrace,
      );

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
      developer.log('🚀 Sending message to AI', name: 'ChatController');

      // Build conversation from database messages
      final conversation = _buildConversationHistory(dbMessages);

      developer.log(
        '📚 Built conversation with ${conversation.length} messages',
        name: 'ChatController',
      );

      // Get shell tools for LLM
      final tools = shellTools;

      developer.log(
        '🔧 Using ${tools.length} shell tools',
        name: 'ChatController',
      );

      // Collect response
      final buffer = StringBuffer();
      final collectedToolCalls = <_ToolCallRequest>[];
      List<llm.ChatMessage>? conversationState;

      var hasStartedStreaming = false;

      await for (final chunk in _llmService.sendMessageWithConversation(
        conversation,
        messageContent,
        tools: tools,
      )) {
        if (chunk is Map) {
          final type = chunk['type'] as String?;

          if (type == 'tool_call') {
            developer.log(
              '🔧 Tool call received: ${chunk['name']}',
              name: 'ChatController',
            );

            final toolCall = chunk['toolCall'] as llm.ToolCall?;
            if (toolCall != null) {
              collectedToolCalls.add(
                _ToolCallRequest(
                  id: toolCall.id,
                  name: chunk['name'] as String,
                  params: chunk['params'] as Map<String, dynamic>,
                  toolCall: toolCall,
                ),
              );
            }
          } else if (type == 'completion') {
            developer.log(
              '🏁 Completion event received',
              name: 'ChatController',
            );

            conversationState = chunk['conversation'] as List<llm.ChatMessage>?;
          }
        } else if (chunk is String) {
          buffer.write(chunk);

          // Notify streaming callbacks with the pre-generated message ID
          if (!hasStartedStreaming) {
            startStreaming(messageId);
            hasStartedStreaming = true;
          }

          updateStreamingText(buffer.toString());
        }
      }

      // Stop streaming when complete
      if (hasStartedStreaming) {
        stopStreaming();
      }

      developer.log('✅ AI response complete', name: 'ChatController');

      return _MessageResult(
        textResponse: buffer.toString(),
        toolCalls: collectedToolCalls.isEmpty ? null : collectedToolCalls,
        conversationState: conversationState,
      );
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
    required Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
        executeAction,
  }) async {
    developer.log(
      '🚀 Executing ${selectedActions.length} actions',
      name: 'ChatController',
    );

    // First, save the assistant's message with tool calls to preserve conversation state
    final pendingCalls = state.pendingToolCalls;
    final assistantText = state.assistantTextBeforeTools;

    if (pendingCalls != null && pendingCalls.isNotEmpty) {
      // Generate message ID upfront
      final assistantMessageId = _messageDao.generateMessageId();

      // Create the ChatMessage with tool calls
      final chatMessage = llm.ChatMessage.toolUse(
        toolCalls: pendingCalls,
        content: assistantText ?? '',
      );

      // Use text content for display, full structure in metadata
      final displayContent = assistantText ?? '[Tool calls: ${pendingCalls.length}]';

      await _messageDao.insertMessageWithId(
        id: assistantMessageId,
        sessionId: sessionId,
        userId: 'ai',
        userName: 'Ops Agent',
        content: displayContent,
        metadata: jsonEncode(chatMessage.toStorageJson()),
      );

      developer.log(
        '💾 Saved assistant message with ${pendingCalls.length} tool calls',
        name: 'ChatController',
      );
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

        developer.log(
          '🔄 Executing action ${i + 1}/${selectedActions.length}',
          name: 'ChatController',
        );
      }

      // Clear execution progress, show loading for LLM response
      state = state.copyWith(executionProgress: null, isLoading: true);

      // Execute tool calls
      final result = await _executeToolCalls(
        toolCalls: selectedActions.map((action) {
          // Find the matching tool call from our state
          final pendingCalls = state.pendingToolCalls;
          if (pendingCalls == null) {
            throw Exception('No pending tool calls in state');
          }

          // Find matching tool call by ID
          llm.ToolCall? matchingToolCall;
          for (final tc in pendingCalls) {
            if (tc.id == action.id) {
              matchingToolCall = tc;
              break;
            }
          }

          if (matchingToolCall == null) {
            throw Exception('Tool call not found: ${action.id}');
          }

          return _ToolCallRequest(
            id: action.id,
            name: action.actionName,
            params: action.params,
            toolCall: matchingToolCall,
          );
        }).toList(),
        conversationState: state.conversationForToolCalls!,
        executeAction: executeAction,
      );

      // Save tool result messages
      for (var i = 0; i < result.toolCalls.length; i++) {
        final toolCall = result.toolCalls[i];
        final toolResult = result.toolResults[toolCall.id] ?? 'No result';

        // Create the ChatMessage with tool results
        final chatMessage = llm.ChatMessage.toolResult(
          results: [toolCall.toolCall],
          content: toolResult,
        );

        await _messageDao.insertMessageWithId(
          sessionId: sessionId,
          userId: 'tool',
          userName: 'Tool',
          content: toolResult,
          metadata: jsonEncode(chatMessage.toStorageJson()),
        );
      }

      // Handle follow-up tool calls
      if (result.hasFollowUp) {
        final followUp = result.followUpResult!;

        // Show approval overlay for follow-up
        if (followUp.toolCalls != null) {
          final actions = followUp.toolCalls!.map((tc) {
            return CommandAction(
              id: tc.id,
              actionName: tc.name,
              params: tc.params,
            );
          }).toList();

          state = state.copyWith(
            pendingActions: actions,
            conversationForToolCalls: followUp.conversationState,
            pendingToolCalls: followUp.toolCalls!.map((tc) => tc.toolCall).toList(),
            assistantTextBeforeTools: followUp.textResponse,
            isLoading: false,
          );

          return;
        }

        // Save follow-up text response
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
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error executing actions: $e',
        name: 'ChatController',
        error: e,
        stackTrace: stackTrace,
      );

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
    required List<_ToolCallRequest> toolCalls,
    required List<llm.ChatMessage> conversationState,
    required Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
        executeAction,
  }) async {
    developer.log(
      '🚀 Executing ${toolCalls.length} tool calls',
      name: 'ChatController',
    );

    final toolResults = <String, String>{};
    final chatMessages = <String>[];

    try {
      // Execute each tool call
      for (var i = 0; i < toolCalls.length; i++) {
        final toolCall = toolCalls[i];

        developer.log(
          '🔄 Executing tool ${i + 1}/${toolCalls.length}: ${toolCall.name}',
          name: 'ChatController',
        );

        // Execute the action
        final result = await executeAction(toolCall.name, toolCall.params);

        // Build result message
        final resultMessage = _formatExecutionResult(
          toolCall.command,
          result['success'] as bool,
          result['data'],
          result['error'],
        );

        chatMessages.add(resultMessage);

        // Map result for LLM
        toolResults[toolCall.id] = result['success'] as bool
            ? result['data']?.toString() ?? 'Success'
            : 'Error: ${result['error']}';
      }

      developer.log(
        '🔄 Continuing conversation with ${toolResults.length} tool results',
        name: 'ChatController',
      );

      // Get tools for potential follow-up
      final tools = shellTools;

      // Build updated conversation with tool use message already included
      final updatedConversation = List<llm.ChatMessage>.from(conversationState);

      // Add the assistant's tool use message
      updatedConversation.add(
        llm.ChatMessage.toolUse(
          toolCalls: toolCalls.map((tc) => tc.toolCall).toList(),
          content: '',
        ),
      );

      developer.log(
        '📋 Updated conversation has ${updatedConversation.length} messages (added tool use)',
        name: 'ChatController',
      );

      // Continue conversation with tool results
      final followUpResult = await _continueWithToolResults(
        conversationState: updatedConversation,
        toolCalls: toolCalls.map((tc) => tc.toolCall).toList(),
        toolResults: toolResults,
        tools: tools,
      );

      return _ToolExecutionResult(
        toolResults: toolResults,
        chatMessages: chatMessages,
        toolCalls: toolCalls,
        followUpResult: followUpResult,
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error executing tool calls: $e',
        name: 'ChatController',
        error: e,
        stackTrace: stackTrace,
      );

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
    required List<llm.ChatMessage> conversationState,
    required List<llm.ToolCall> toolCalls,
    required Map<String, String> toolResults,
    required List<llm.Tool> tools,
  }) async {
    try {
      final buffer = StringBuffer();
      final followUpToolCalls = <_ToolCallRequest>[];
      List<llm.ChatMessage>? newConversationState;

      await for (final chunk in _llmService.continueWithToolResults(
        conversationState,
        toolCalls,
        toolResults,
        tools: tools,
      )) {
        if (chunk is Map) {
          final type = chunk['type'] as String?;

          if (type == 'tool_call') {
            developer.log(
              '🔧 Follow-up tool call received: ${chunk['name']}',
              name: 'ChatController',
            );

            final toolCall = chunk['toolCall'] as llm.ToolCall?;
            if (toolCall != null) {
              followUpToolCalls.add(
                _ToolCallRequest(
                  id: toolCall.id,
                  name: chunk['name'] as String,
                  params: chunk['params'] as Map<String, dynamic>,
                  toolCall: toolCall,
                ),
              );
            }
          } else if (type == 'completion') {
            developer.log(
              '🏁 Follow-up completion event',
              name: 'ChatController',
            );

            newConversationState = chunk['conversation'] as List<llm.ChatMessage>?;
          }
        } else if (chunk is String) {
          buffer.write(chunk);
        }
      }

      // Return result if we have follow-up tool calls or text
      if (followUpToolCalls.isNotEmpty || buffer.isNotEmpty) {
        return _MessageResult(
          textResponse: buffer.toString(),
          toolCalls: followUpToolCalls.isEmpty ? null : followUpToolCalls,
          conversationState: newConversationState,
        );
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

  /// Cancel pending actions
  void cancelActions() {
    developer.log('🧹 Cancelling pending actions', name: 'ChatController');

    state = state.copyWith(
      pendingActions: null,
      conversationForToolCalls: null,
      pendingToolCalls: null,
      assistantTextBeforeTools: null,
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
    StateNotifierProvider.family<ChatController, ChatState, String?>((ref, sessionId) {
  return ChatController(
    messageDao: ref.watch(databaseProvider).messageDao,
    sessionDao: ref.watch(databaseProvider).sessionDao,
    llmService: ref.watch(llmServiceProvider),
    sessionId: sessionId,
  );
});

// Internal helper classes

/// Result of sending a message to the AI
class _MessageResult {
  final String? textResponse;
  final List<_ToolCallRequest>? toolCalls;
  final List<llm.ChatMessage>? conversationState;
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

/// A tool call request from the AI
class _ToolCallRequest {
  final String id;
  final String name;
  final Map<String, dynamic> params;
  final llm.ToolCall toolCall;

  const _ToolCallRequest({
    required this.id,
    required this.name,
    required this.params,
    required this.toolCall,
  });

  /// Get the command from params (if applicable)
  String get command => params['command'] as String? ?? 'unknown';

  /// Get the explanation from params (if applicable)
  String get explanation => params['explanation'] as String? ?? '';
}

/// Result of executing tool calls
class _ToolExecutionResult {
  final Map<String, String> toolResults;
  final List<String> chatMessages;
  final List<_ToolCallRequest> toolCalls;
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
  bool get hasFollowUp => followUpResult != null && followUpResult!.hasToolCalls;
}
