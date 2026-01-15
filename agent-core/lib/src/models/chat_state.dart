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
/// Contains only transient UI state that doesn't belong in providers.
/// Loading state is now managed via SessionMutexDao (currentSessionLockProvider)
/// to ensure consistency between local and remote execution.
@freezed
class ChatState with _$ChatState {
  const factory ChatState({
    // Execution progress tracking
    ExecutionProgress? executionProgress,

    // Error state
    String? error,
  }) = _ChatState;

  const ChatState._();

  /// Check if currently executing commands
  bool get isExecuting => executionProgress != null;

  /// Check if in error state
  bool get hasError => error != null;
}
