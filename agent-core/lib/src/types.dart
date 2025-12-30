import 'package:llm_dart/llm_dart.dart';

/// Represents a tool call that needs approval
class PendingToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final ToolCall originalToolCall;

  const PendingToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    required this.originalToolCall,
  });
}

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

/// Callback types for the agent loop
typedef LlmStreamFunction = Stream<ChatStreamEvent> Function(
  List<ChatMessage> conversation,
  List<Tool> tools,
);

typedef ApprovalFunction = Future<List<PendingToolCall>?> Function(
  List<PendingToolCall> toolCalls,
);

typedef ToolExecutionFunction = Future<String> Function(ToolCall toolCall);

typedef TextDeltaCallback = void Function(String delta);

typedef MessageCallback = Future<void> Function(ChatMessage message,
    {String? messageId});

typedef ToolResultMessageCallback = Future<void> Function(
    ChatMessage toolResultMessage,
    {String? messageId,
    ChatMessage? toolCallMessage});

/// Optional callback to get fresh conversation (e.g., from database)
/// If provided, called at the start of each iteration instead of using in-memory list
typedef ConversationProvider = Future<List<ChatMessage>> Function();
