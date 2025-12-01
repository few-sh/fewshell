import 'dart:convert';

import 'package:llm_dart/llm_dart.dart';

import 'agent_adapter/agent_adapter.dart';
import 'types.dart';
import 'dart:developer' as developer;

/// Runs the agent loop: LLM → tool calls → approval → execution → repeat
///
/// This is the core agent loop extracted for reuse between client and server.
/// All persistence, UI, and streaming state management is handled by callbacks.
///
/// Parameters:
/// - [adapter]: The AgentAdapter that defines the prompt strategy and parses results
/// - [llmStream]: Function to stream chat completion from LLM
/// - [conversation]: Initial conversation messages (used if getConversation is null)
/// - [getConversation]: Optional callback to get fresh conversation each iteration
///   (useful when conversation is persisted to DB and needs to be reloaded)
/// - [requestApproval]: Callback to request user approval for tool calls
/// - [executeToolCall]: Callback to execute a single tool call
/// - [onTextDelta]: Optional callback for streaming text deltas
/// - [onAssistantMessage]: Optional callback when assistant message is complete
/// - [onToolResultMessage]: Optional callback when tool results are ready
/// - [onUserMessage]: Optional callback when a user message (e.g. error recovery) is generated
///
/// Returns [AgentLoopResult] indicating how the loop terminated:
/// - [AgentLoopCompleted]: No more tool calls, conversation complete
/// - [AgentLoopCancelled]: User cancelled tool approval
/// - [AgentLoopError]: An error occurred
Future<AgentLoopResult> runAgentLoop({
  required AgentAdapter adapter,
  required LlmStreamFunction llmStream,
  List<ChatMessage>? conversation,
  ConversationProvider? getConversation,
  required ApprovalFunction requestApproval,
  required ToolExecutionFunction executeToolCall,
  TextDeltaCallback? onTextDelta,
  MessageCallback? onAssistantMessage,
  MessageCallback? onToolResultMessage,
  MessageCallback? onUserMessage,
}) async {
  // Work with a mutable copy if using in-memory conversation
  var messages = conversation != null
      ? List<ChatMessage>.from(conversation)
      : <ChatMessage>[];

  try {
    while (true) {
      // Get fresh conversation if provider is available (e.g., from database)
      if (getConversation != null) {
        messages = await getConversation();
      }

      // Stream from LLM
      final streamResult = await _streamFromLlm(
        llmStream: llmStream,
        tools: adapter.tools,
        conversation: messages,
        onTextDelta: onTextDelta,
      );

      // Check for error
      if (streamResult.error != null) {
        return AgentLoopError(streamResult.error!);
      }

      // Validate and parse the result using the adapter
      final validationResult = adapter.validate(
        streamResult.text,
        streamResult.toolCalls,
      );

      List<ToolCall> currentToolCalls;

      switch (validationResult) {
        case AdapterSuccess(toolCalls: final calls):
          developer.log(
            'Adapter validated ${calls.length} tool calls',
            name: 'AgentLoop',
          );
          currentToolCalls = calls;

        case AdapterTurnComplete(content: final content):
          // Valid termination of the turn
          if (content.isNotEmpty && onAssistantMessage != null) {
            await onAssistantMessage(ChatMessage.assistant(content));
          }
          return const AgentLoopCompleted();

        case AdapterFailure(userErrorMessage: final errorMessage):
          // IMPORTANT: We must add the assistant's invalid message to the history
          // so the LLM sees what it did wrong.
          if (streamResult.text.isNotEmpty) {
            final invalidMessage = ChatMessage.assistant(streamResult.text);
            messages.add(invalidMessage);
            if (onAssistantMessage != null) {
              await onAssistantMessage(invalidMessage);
            }
          }

          // Handle format error by sending a user message (observation) back to the agent
          // This allows the agent to self-correct
          final userMsg = ChatMessage.user(errorMessage);

          // Add to in-memory conversation
          messages.add(userMsg);

          // Persist if callback provided
          if (onUserMessage != null) {
            await onUserMessage(userMsg);
          }

          // Continue loop to let agent try again
          continue;
      }

      // Convert to pending tool calls for approval
      final pendingCalls = <PendingToolCall>[];
      for (final tc in currentToolCalls) {
        Map<String, dynamic> args;
        try {
          args = tc.function.arguments.isNotEmpty
              ? Map<String, dynamic>.from(jsonDecode(tc.function.arguments))
              : <String, dynamic>{};
        } catch (e) {
          return AgentLoopError(
            'Failed to parse JSON arguments for tool ${tc.function.name}: $e',
          );
        }
        pendingCalls.add(
          PendingToolCall(
            id: tc.id,
            name: tc.function.name,
            arguments: args,
            originalToolCall: tc,
          ),
        );
      }

      // Request approval
      final approved = await requestApproval(pendingCalls);

      // User cancelled
      if (approved == null) {
        return const AgentLoopCancelled();
      }

      // Get the approved ToolCalls
      final approvedToolCalls =
          approved.map((p) => p.originalToolCall).toList();

      // Build and save assistant message with tool use
      final assistantMessage = ChatMessage.toolUse(
        toolCalls: approvedToolCalls,
        content: streamResult.text,
      );
      // Add to in-memory conversation (will be overwritten if using getConversation)
      messages.add(assistantMessage);
      if (onAssistantMessage != null) {
        await onAssistantMessage(assistantMessage);
      }

      // Execute each approved tool call
      final results = <ToolCall>[];
      for (final toolCall in approvedToolCalls) {
        String resultString;
        try {
          resultString = await executeToolCall(toolCall);
        } catch (e) {
          // Return error as result so LLM can reason about it
          resultString = jsonEncode({
            'error': 'Tool "${toolCall.function.name}" failed to execute.',
            'details': e.toString(),
          });
        }
        results.add(
          ToolCall(
            id: toolCall.id,
            callType: toolCall.callType,
            function: FunctionCall(
              name: toolCall.function.name,
              arguments: resultString,
            ),
          ),
        );
      }

      // Build tool result message
      final combinedContent =
          results.map((r) => r.function.arguments).join('\n---\n');
      final toolResultMessage = ChatMessage.toolResult(
        results: results,
        content: combinedContent,
      );
      // Add to in-memory conversation (will be overwritten if using getConversation)
      messages.add(toolResultMessage);
      if (onToolResultMessage != null) {
        await onToolResultMessage(toolResultMessage);
      }

      // Loop continues with updated conversation
    }
  } catch (e) {
    return AgentLoopError('Unexpected error in agent loop: $e');
  }
}

/// Internal result from streaming LLM response
class _StreamResult {
  final String text;
  final List<ToolCall> toolCalls;
  final String? error;

  _StreamResult({
    required this.text,
    required this.toolCalls,
    this.error,
  });
}

/// Streams response from LLM and collects text/tool calls
Future<_StreamResult> _streamFromLlm({
  required LlmStreamFunction llmStream,
  required List<Tool> tools,
  required List<ChatMessage> conversation,
  TextDeltaCallback? onTextDelta,
}) async {
  final buffer = StringBuffer();
  final toolCallMap = <String, ToolCall>{};

  try {
    await for (final event in llmStream(conversation, tools)) {
      switch (event) {
        case TextDeltaEvent(delta: final delta):
          buffer.write(delta);
          onTextDelta?.call(delta);

        case ToolCallDeltaEvent(toolCall: final delta):
          final id = delta.id;
          if (toolCallMap.containsKey(id)) {
            // Aggregate arguments
            final existing = toolCallMap[id]!;
            final newArgs =
                existing.function.arguments + delta.function.arguments;

            // Create updated tool call
            toolCallMap[id] = ToolCall(
              id: id,
              callType: existing.callType,
              function: FunctionCall(
                name:
                    existing.function.name, // Name usually comes in first delta
                arguments: newArgs,
              ),
            );
          } else {
            // New tool call
            toolCallMap[id] = delta;
          }

        case ThinkingDeltaEvent():
          // Ignore thinking events for now
          break;

        case CompletionEvent():
          // Stream complete
          break;

        case ErrorEvent(error: final error):
          return _StreamResult(
            text: buffer.toString(),
            toolCalls: [],
            error: error.message,
          );
      }
    }

    return _StreamResult(
      text: buffer.toString(),
      toolCalls: toolCallMap.values.toList(),
    );
  } catch (e) {
    return _StreamResult(
      text: buffer.toString(),
      toolCalls: [],
      error: e.toString(),
    );
  }
}
