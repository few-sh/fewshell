import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_dart/llm_dart.dart' as llm;
import '../models/chat_state.dart';
import '../repositories/chat_repository.dart';
import '../components/multi_command_approval_overlay.dart';

/// Controller for chat session state management
/// Handles all business logic for chat interactions, tool execution, and message syncing
class ChatController extends StateNotifier<ChatState> {
  final ChatRepository _repository;
  final String? sessionId;

  ChatController(this._repository, this.sessionId) : super(const ChatState()) {
    _initialize();
  }

  /// Initialize controller
  Future<void> _initialize() async {
    // Controller is ready - no need to cache model identifier
    // UI can fetch it directly from providers when needed
  }

  /// Reset state when session changes (called by provider when session changes)
  void resetForNewSession() {
    state = const ChatState();
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
    required List<dynamic>
    dbMessages, // Database messages to build conversation from
    required bool isFirstMessage,
  }) async {
    developer.log('🎯 sendMessage called', name: 'ChatController');

    // Save user's message to database
    // Note: The UI already has the message (added by AiChatWidget), we just save it
    final userMessageId = await _repository.saveUserMessage(
      sessionId: sessionId,
      content: content,
    );

    developer.log(
      'User message saved with ID: $userMessageId',
      name: 'ChatController',
    );

    // Update session description if first message
    await _repository.updateSessionDescriptionIfNeeded(
      sessionId: sessionId,
      messageContent: content,
      isFirstMessage: isFirstMessage,
    );

    // Set loading state
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Check if LLM is configured (no need to cache identifier)
      final isConfigured = await _repository.isConfigured();

      if (!isConfigured) {
        developer.log('❌ LLM not configured', name: 'ChatController');

        const configMessage =
            "⚠️ No LLM configured. Please go to Settings → AI Models to configure an LLM provider.";

        // Save warning message
        await _repository.saveAiMessage(
          sessionId: sessionId,
          content: configMessage,
        );

        state = state.copyWith(isLoading: false);
        return;
      }

      // Generate message ID upfront for consistent tracking across streaming and DB
      final aiMessageId = _repository.generateMessageId();

      // Send message to AI with streaming support
      final result = await _repository.sendMessageToAI(
        messageContent: content,
        dbMessages: dbMessages,
        messageId: aiMessageId, // Use pre-generated ID
        onStreamStart: (messageId) {
          startStreaming(messageId);
        },
        onStreamChunk: (messageId, text) {
          updateStreamingText(text);
        },
        onStreamEnd: (messageId) {
          stopStreaming();
        },
      );

      // Handle error
      if (result.hasError) {
        developer.log('❌ Error: ${result.error}', name: 'ChatController');

        final errorMessage = 'Sorry, I encountered an error: ${result.error}';
        await _repository.saveAiMessage(
          sessionId: sessionId,
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
        // Save with the pre-generated ID that was used during streaming
        await _repository.saveAiMessage(
          id: aiMessageId,
          sessionId: sessionId,
          content: result.textResponse!,
        );

        // Message is already in UI from streaming, no need to add it again
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
      await _repository.saveAiMessage(
        sessionId: sessionId,
        content: errorMessage,
      );

      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Execute multiple approved actions
  Future<void> executeActions({
    required List<CommandAction> selectedActions,
    required List<CommandAction> allActions,
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
      final assistantMessageId = _repository.generateMessageId();

      // Save the assistant message with tool calls
      await _repository.saveAssistantMessageWithToolCalls(
        id: assistantMessageId,
        sessionId: sessionId,
        toolCalls: pendingCalls,
        textContent: assistantText,
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

      // Note: Skipped messages are not displayed in new UI (database-driven)
      // The UI will only show messages that were actually executed

      // Execute tool calls through repository
      final result = await _repository.executeToolCalls(
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

          return ToolCallRequest(
            id: action.id,
            name: action.actionName,
            params: action.params,
            toolCall: matchingToolCall,
          );
        }).toList(),
        conversationState: state.conversationForToolCalls!,
        executeAction: executeAction,
      );

      // Save formatted tool result messages (these are now nicely formatted and user-visible)
      for (var i = 0; i < result.toolCalls.length; i++) {
        final toolCall = result.toolCalls[i];

        // Note: Formatted result messages are not displayed in new UI
        // Only raw tool results are saved for LLM conversation

        // Save raw result for LLM conversation with complete ToolCall structure
        final toolResult = result.toolResults[toolCall.id] ?? 'No result';
        await _repository.saveToolResultMessage(
          sessionId: sessionId,
          toolCalls: [toolCall.toolCall],
          resultContent: toolResult,
        );
      }

      // Handle follow-up tool calls
      if (result.hasFollowUp) {
        final followUp = result.followUpResult!;

        // Show approval overlay for follow-up (don't display messages yet)
        if (followUp.toolCalls != null) {
          // Show approval overlay for follow-up
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
            pendingToolCalls: followUp.toolCalls!
                .map((tc) => tc.toolCall)
                .toList(),
            assistantTextBeforeTools: followUp.textResponse,
            isLoading: false,
          );

          return;
        }

        // Save follow-up text response
        if (followUp.hasTextResponse) {
          // Save follow-up response to database (will automatically display via stream)
          await _repository.saveAiMessage(
            sessionId: sessionId,
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
      await _repository.saveAiMessage(
        sessionId: sessionId,
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
/// Controller automatically resets when sessionId parameter changes (Riverpod creates new instance)
final chatControllerProvider =
    StateNotifierProvider.family<ChatController, ChatState, String?>((
      ref,
      sessionId,
    ) {
      return ChatController(ref.watch(chatRepositoryProvider), sessionId);
    });
