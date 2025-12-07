import 'package:freezed_annotation/freezed_annotation.dart';

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

    // Execution progress tracking
    ExecutionProgress? executionProgress,

    // Streaming state
    String? streamingMessageId,

    // Error state
    String? error,
  }) = _ChatState;

  const ChatState._();

  /// Check if currently executing commands
  bool get isExecuting => executionProgress != null;

  /// Check if in error state
  bool get hasError => error != null;
}
