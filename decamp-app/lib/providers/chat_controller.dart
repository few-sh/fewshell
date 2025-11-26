import 'dart:developer' as developer;
import 'package:agent_core/agent_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_state.dart';
import '../providers/session_controller_provider.dart';
import '../components/multi_command_approval_overlay.dart';

/// Controller for chat session UI state management.
///
/// This is a thin layer over SessionController that manages UI-specific state
/// like loading indicators and streaming text. All persistence and execution
/// is delegated to SessionController (Quake-style unified interface).
class ChatController extends StateNotifier<ChatState> {
  final SessionController _sessionController;

  ChatController({required SessionController sessionController})
    : _sessionController = sessionController,
      super(const ChatState());

  /// Reset state when session changes
  void resetForNewSession() {
    state = const ChatState();
  }

  // ============================================================
  // Message Sending
  // ============================================================

  /// Send a message to the AI.
  ///
  /// The SessionController handles:
  /// - Persisting the user message
  /// - Running the agent loop
  /// - Persisting AI responses and tool results
  ///
  /// This controller just manages UI state (loading, streaming, errors).
  Future<void> sendMessage({
    required String content,
    required String sessionId,
    required Future<List<ToolAction>?> Function(List<ToolAction>)
        requestApproval,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _runAgentLoop(
        sessionId: sessionId,
        content: content,
        requestApproval: requestApproval,
      );
      _handleResult(result);
    } catch (e) {
      developer.log('❌ Error: $e', name: 'ChatController');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Run agent loop with new content
  Future<AgentLoopResult> _runAgentLoop({
    required String sessionId,
    required String content,
    required Future<List<ToolAction>?> Function(List<ToolAction>)
        requestApproval,
  }) async {
    var hasStartedStreaming = false;
    final streamingBuffer = StringBuffer();

    return await _sessionController.sendMessage(
      sessionId: sessionId,
      content: content,
      onTextDelta: (delta) {
        streamingBuffer.write(delta);
        if (!hasStartedStreaming) {
          startStreaming('streaming');
          hasStartedStreaming = true;
        }
        updateStreamingText(streamingBuffer.toString());
      },
      onMessage: (message) {
        if (hasStartedStreaming) {
          stopStreaming();
          hasStartedStreaming = false;
          streamingBuffer.clear();
        }
      },
      requestApproval: (pendingCalls) async {
        final actions = _pendingToolCallsToActions(pendingCalls);
        final selectedActions = await requestApproval(actions);

        if (selectedActions == null) return null;

        return pendingCalls.indexed
            .where((e) => selectedActions.any((a) => a.id == e.$2.id))
            .map((e) => e.$1)
            .toList();
      },
    );
  }

  /// Continue conversation without adding a user message.
  /// Used for edit/resend operations.
  Future<AgentLoopResult> _continueConversation({
    required String sessionId,
    required Future<List<ToolAction>?> Function(List<ToolAction>)
        requestApproval,
  }) async {
    var hasStartedStreaming = false;
    final streamingBuffer = StringBuffer();

    return await _sessionController.continueConversation(
      sessionId: sessionId,
      onTextDelta: (delta) {
        streamingBuffer.write(delta);
        if (!hasStartedStreaming) {
          startStreaming('streaming');
          hasStartedStreaming = true;
        }
        updateStreamingText(streamingBuffer.toString());
      },
      onMessage: (message) {
        if (hasStartedStreaming) {
          stopStreaming();
          hasStartedStreaming = false;
          streamingBuffer.clear();
        }
      },
      requestApproval: (pendingCalls) async {
        final actions = _pendingToolCallsToActions(pendingCalls);
        final selectedActions = await requestApproval(actions);

        if (selectedActions == null) return null;

        return pendingCalls.indexed
            .where((e) => selectedActions.any((a) => a.id == e.$2.id))
            .map((e) => e.$1)
            .toList();
      },
    );
  }

  void _handleResult(AgentLoopResult result) {
    switch (result) {
      case AgentLoopCompleted():
        developer.log('✅ Agent loop completed', name: 'ChatController');
        state = state.copyWith(isLoading: false);
      case AgentLoopCancelled():
        developer.log('🚨 User cancelled', name: 'ChatController');
        state = state.copyWith(isLoading: false);
      case AgentLoopError(message: final errorMsg):
        developer.log('❌ Agent loop error: $errorMsg', name: 'ChatController');
        state = state.copyWith(isLoading: false, error: errorMsg);
    }
  }

  List<ToolAction> _pendingToolCallsToActions(List<PendingToolCall> toolCalls) {
    return toolCalls.map((tc) {
      return ToolAction(id: tc.id, toolName: tc.name, params: tc.arguments);
    }).toList();
  }

  // ============================================================
  // Edit & Resend
  // ============================================================

  /// Edit a message and resend from that point.
  /// Updates the message content, deletes all messages after it, then resends.
  Future<void> editMessage({
    required String messageId,
    required String newContent,
    required String sessionId,
    required Future<List<ToolAction>?> Function(List<ToolAction>)
        requestApproval,
  }) async {
    developer.log('✏️ Editing message: $messageId', name: 'ChatController');
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get the message to find its timestamp
      final message = await _sessionController.getMessage(messageId);
      if (message == null) {
        developer.log(
          '❌ Message not found: $messageId',
          name: 'ChatController',
        );
        state = state.copyWith(isLoading: false);
        return;
      }

      // Update the message content
      await _sessionController.updateMessageContent(messageId, newContent);
      developer.log('💾 Updated message content', name: 'ChatController');

      // Delete all messages AFTER this one
      final deletedCount = await _sessionController.deleteMessagesAfter(
        sessionId,
        message.createdAt,
      );
      developer.log(
        '🗑️ Deleted $deletedCount messages after edit',
        name: 'ChatController',
      );

      // Continue from the edited message
      final result = await _continueConversation(
        sessionId: sessionId,
        requestApproval: requestApproval,
      );
      _handleResult(result);
    } catch (e) {
      developer.log('❌ Edit error: $e', name: 'ChatController');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Resend from a message: delete all messages after it, then resend.
  Future<void> resendMessage({
    required String messageId,
    required String sessionId,
    required Future<List<ToolAction>?> Function(List<ToolAction>)
        requestApproval,
  }) async {
    developer.log('🔄 Resending from: $messageId', name: 'ChatController');
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get the message to find its timestamp
      final message = await _sessionController.getMessage(messageId);
      if (message == null) {
        developer.log(
          '❌ Message not found: $messageId',
          name: 'ChatController',
        );
        state = state.copyWith(isLoading: false);
        return;
      }

      // Delete all messages AFTER this one
      final deletedCount = await _sessionController.deleteMessagesAfter(
        sessionId,
        message.createdAt,
      );
      developer.log(
        '🗑️ Deleted $deletedCount messages',
        name: 'ChatController',
      );

      // Continue from that point
      final result = await _continueConversation(
        sessionId: sessionId,
        requestApproval: requestApproval,
      );
      _handleResult(result);
    } catch (e) {
      developer.log('❌ Resend error: $e', name: 'ChatController');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Branch the session by creating a copy up to a specific message.
  /// Returns the new session ID.
  Future<String?> branchSession({
    required String messageId,
    required String sessionId,
  }) async {
    // TODO: Implement via SessionController when branch support is added
    developer.log(
      '⚠️ Branch not yet implemented via SessionController',
      name: 'ChatController',
    );
    return null;
  }

  // ============================================================
  // Streaming State
  // ============================================================

  void startStreaming(String messageId) {
    state = state.copyWith(streamingMessageId: messageId, streamingText: '');
  }

  void updateStreamingText(String text) {
    state = state.copyWith(streamingText: text);
  }

  void stopStreaming() {
    state = state.copyWith(streamingMessageId: null, streamingText: '');
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for ChatController.
/// Requires SessionController to be available.
final chatControllerProvider =
    StateNotifierProvider.family<ChatController, ChatState, String?>((
      ref,
      sessionId,
    ) {
      final sessionControllerAsync = ref.watch(sessionControllerProvider);

      // Return a "loading" controller if SessionController not ready
      final sessionController = sessionControllerAsync.valueOrNull;
      if (sessionController == null) {
        // Return a dummy controller that shows loading state
        // This shouldn't happen in practice since we wait for SessionController
        throw Exception('SessionController not available');
      }

      return ChatController(sessionController: sessionController);
    });
