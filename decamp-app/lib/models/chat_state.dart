import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:llm_dart/llm_dart.dart';
import '../components/multi_command_approval_overlay.dart';

part 'chat_state.freezed.dart';

/// Execution progress information
@freezed
class ExecutionProgress with _$ExecutionProgress {
  const factory ExecutionProgress({
    required int currentCommand,
    required int totalCommands,
    required String commandName,
  }) = _ExecutionProgress;
}

/// State for the chat session
/// Contains only transient UI state that doesn't belong in providers
/// Data that exists in providers (like currentModelIdentifier) should be accessed directly from providers
@freezed
class ChatState with _$ChatState {
  const factory ChatState({
    // Loading state
    @Default(false) bool isLoading,

    // Pending actions approval (for multi-command support)
    List<CommandAction>? pendingActions,

    // Execution progress tracking
    ExecutionProgress? executionProgress,

    // Conversation state for tool calls (following official llm_dart pattern)
    List<ChatMessage>? conversationForToolCalls,
    List<ToolCall>? pendingToolCalls,
    String? assistantTextBeforeTools,

    // Streaming state
    String? streamingMessageId,
    @Default('') String streamingText,

    // Error state
    String? error,
  }) = _ChatState;

  const ChatState._();

  /// Check if there are pending actions to approve
  bool get hasPendingActions =>
      pendingActions != null && pendingActions!.isNotEmpty;

  /// Check if currently executing commands
  bool get isExecuting => executionProgress != null;

  /// Check if in error state
  bool get hasError => error != null;
}
