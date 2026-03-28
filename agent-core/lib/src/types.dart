import 'dart:convert';

import 'package:llm_dart/llm_dart.dart';

import 'database/project_database.dart';

/// Represents a tool call that needs approval
class PendingToolCall {
  final Map<String, dynamic> arguments;
  final ToolCall originalToolCall;

  String get id => originalToolCall.id;
  String get name => originalToolCall.function.name;

  const PendingToolCall({
    required this.arguments,
    required this.originalToolCall,
  });

  PendingToolCall withArguments(Map<String, dynamic> newArguments) {
    return PendingToolCall(
      arguments: newArguments,
      originalToolCall: originalToolCall,
    );
  }

  Map<String, dynamic> toApprovalRequestJson() {
    return {
      'id': id,
      'name': name,
      'arguments': arguments,
    };
  }

  Map<String, dynamic> toApprovalResponseJson() {
    return {
      'id': id,
      'arguments': arguments,
    };
  }

  factory PendingToolCall.fromApprovalRequestJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final name = json['name'] as String;
    final args = Map<String, dynamic>.from(json['arguments'] as Map);

    return PendingToolCall(
      arguments: args,
      originalToolCall: ToolCall(
        id: id,
        callType: 'function',
        function: FunctionCall(
          name: name,
          arguments: jsonEncode(args),
        ),
      ),
    );
  }
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

typedef ToolResultMessageCallback = Future<void> Function(
    ChatMessage toolResultMessage,
    {String? messageId,
    ChatMessage? toolCallMessage});

/// Optional callback to get fresh conversation (e.g., from database)
/// If provided, called at the start of each iteration instead of using in-memory list
typedef ConversationProvider = Future<List<MessageEntity>> Function();
