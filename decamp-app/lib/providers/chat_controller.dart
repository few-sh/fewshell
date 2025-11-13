import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:llm_dart/llm_dart.dart' as llm;
import '../models/chat_state.dart';
import '../repositories/chat_repository.dart';
import '../components/multi_command_approval_overlay.dart';

/// Controller for chat session state management
/// Handles all business logic for chat interactions, tool execution, and message syncing
class ChatController extends StateNotifier<ChatState> {
  final ChatRepository _repository;
  final String? sessionId;

  // Define users
  final _currentUser = ChatUser(id: 'user', firstName: 'You');
  final _aiUser = ChatUser(id: 'ai', firstName: 'Ops Agent');

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

  /// Get current user
  ChatUser get currentUser => _currentUser;

  /// Get AI user
  ChatUser get aiUser => _aiUser;

  /// Send a message to the AI
  /// Handles saving to database, getting AI response, and managing tool calls
  Future<void> sendMessage({
    required String content,
    required String sessionId,
    required List<Map<String, String>> conversationHistory,
    required bool isFirstMessage,
    required void Function(ChatMessage) addMessageToUI,
  }) async {
    developer.log('🎯 sendMessage called', name: 'ChatController');

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

        // Save and display warning
        final messageId = await _repository.saveAiMessage(
          sessionId: sessionId,
          content: configMessage,
        );

        addMessageToUI(
          ChatMessage(
            text: configMessage,
            user: _aiUser,
            createdAt: DateTime.now(),
            customProperties: {'id': messageId},
          ),
        );

        state = state.copyWith(isLoading: false);
        return;
      }

      // Send message to AI
      final result = await _repository.sendMessageToAI(
        messageContent: content,
        conversationHistory: conversationHistory,
      );

      // Handle error
      if (result.hasError) {
        developer.log('❌ Error: ${result.error}', name: 'ChatController');

        final errorMessage = 'Sorry, I encountered an error: ${result.error}';
        final messageId = await _repository.saveAiMessage(
          sessionId: sessionId,
          content: errorMessage,
        );

        addMessageToUI(
          ChatMessage(
            text: errorMessage,
            user: _aiUser,
            createdAt: DateTime.now(),
            customProperties: {'id': messageId},
          ),
        );

        state = state.copyWith(isLoading: false, error: result.error);
        return;
      }

      // Save tool call messages if any
      if (result.toolCalls != null) {
        for (final toolCall in result.toolCalls!) {
          final messageId = await _repository.saveAiMessage(
            sessionId: sessionId,
            content: toolCall.formattedMessage,
          );

          addMessageToUI(
            ChatMessage(
              text: toolCall.formattedMessage,
              user: _aiUser,
              createdAt: DateTime.now(),
              customProperties: {'id': messageId},
            ),
          );
        }
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
            isSelected: true,
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
        final messageId = await _repository.saveAiMessage(
          sessionId: sessionId,
          content: result.textResponse!,
        );

        addMessageToUI(
          ChatMessage(
            text: result.textResponse!,
            user: _aiUser,
            createdAt: DateTime.now(),
            customProperties: {'id': messageId},
            isMarkdown: true,
          ),
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
      final messageId = await _repository.saveAiMessage(
        sessionId: sessionId,
        content: errorMessage,
      );

      addMessageToUI(
        ChatMessage(
          text: errorMessage,
          user: _aiUser,
          createdAt: DateTime.now(),
          customProperties: {'id': messageId},
        ),
      );

      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Execute multiple approved actions
  Future<void> executeActions({
    required List<CommandAction> selectedActions,
    required String sessionId,
    required Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
    executeAction,
    required void Function(ChatMessage) addMessageToUI,
  }) async {
    developer.log(
      '🚀 Executing ${selectedActions.length} actions',
      name: 'ChatController',
    );

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

      // Save result messages to database and UI
      for (final message in result.chatMessages) {
        final messageId = await _repository.saveAiMessage(
          sessionId: sessionId,
          content: message,
        );

        addMessageToUI(
          ChatMessage(
            text: message,
            user: _aiUser,
            createdAt: DateTime.now(),
            customProperties: {'id': messageId},
            isMarkdown: true,
          ),
        );
      }

      // Handle follow-up tool calls
      if (result.hasFollowUp) {
        final followUp = result.followUpResult!;

        // Save follow-up tool call messages
        if (followUp.toolCalls != null) {
          for (final toolCall in followUp.toolCalls!) {
            final messageId = await _repository.saveAiMessage(
              sessionId: sessionId,
              content: toolCall.formattedMessage,
            );

            addMessageToUI(
              ChatMessage(
                text: toolCall.formattedMessage,
                user: _aiUser,
                createdAt: DateTime.now(),
                customProperties: {'id': messageId},
              ),
            );
          }

          // Show approval overlay for follow-up
          final actions = followUp.toolCalls!.map((tc) {
            return CommandAction(
              id: tc.id,
              actionName: tc.name,
              params: tc.params,
              isSelected: true,
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
          final messageId = await _repository.saveAiMessage(
            sessionId: sessionId,
            content: followUp.textResponse!,
          );

          addMessageToUI(
            ChatMessage(
              text: followUp.textResponse!,
              user: _aiUser,
              createdAt: DateTime.now(),
              customProperties: {'id': messageId},
              isMarkdown: true,
            ),
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
      final messageId = await _repository.saveAiMessage(
        sessionId: sessionId,
        content: errorMessage,
      );

      addMessageToUI(
        ChatMessage(
          text: errorMessage,
          user: _aiUser,
          createdAt: DateTime.now(),
          customProperties: {'id': messageId},
          isMarkdown: true,
        ),
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
