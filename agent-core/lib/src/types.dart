import 'package:llm_dart/llm_dart.dart';

import 'database/project_database.dart';
import 'models/pending_tool_call_list.dart';

export 'models/pending_tool_call_list.dart' show PendingToolCall;

/// Result of the agent loop
sealed class AgentLoopResult {
  const AgentLoopResult();
}

/// Agent completed normally (no more tool calls)
class AgentLoopCompleted extends AgentLoopResult {
  const AgentLoopCompleted();
}

/// User cancelled tool approval
class AgentLoopCancelled extends AgentLoopResult {
  const AgentLoopCancelled();
}

/// An error occurred
class AgentLoopError extends AgentLoopResult {
  final String message;
  final String? messageId;
  const AgentLoopError(this.message, {this.messageId});
}

/// Exception thrown when the agent loop is aborted by the user
class AgentAbortException implements Exception {
  final String message;
  const AgentAbortException([this.message = 'Aborted by user']);
  @override
  String toString() => 'AgentAbortException: $message';
}

/// Callback types for the agent loop
typedef LlmStreamFunction = Stream<ChatStreamEvent> Function(
  List<ChatMessage> conversation,
  List<Tool> tools, {
  CancelToken? cancelToken,
});

typedef ApprovalFunction = Future<List<PendingToolCall>?> Function(
  List<PendingToolCall> toolCalls,
);

typedef ToolExecutionFunction = Future<List<String>> Function(
  MessageEntity toolUseMessage,
  List<ToolCall> approvedToolCalls,
);

typedef TextDeltaCallback = Future<void> Function(String delta);

typedef MessageCallback = Future<void> Function(ChatMessage message,
    {String? messageId});

typedef ToolResultMessageCallback = Future<MessageEntity> Function(
    ChatMessage toolResultMessage,
    {String? messageId,
    ChatMessage? toolCallMessage});

/// Optional callback to get fresh conversation (e.g., from database)
/// If provided, called at the start of each iteration instead of using in-memory list
typedef ConversationProvider = Future<List<MessageEntity>> Function();
