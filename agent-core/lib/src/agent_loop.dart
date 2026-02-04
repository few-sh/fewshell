import 'dart:convert';

import 'package:llm_dart/llm_dart.dart';
import 'package:logging/logging.dart';

import 'types.dart';

final _log = Logger('AgentLoop');

/// Runs the agent loop: LLM → tool calls → approval → execution → repeat
///
/// This is the core agent loop extracted for reuse between client and server.
/// All persistence, UI, and streaming state management is handled by callbacks.
///
/// Parameters:
/// - [llmStream]: Function to stream chat completion from LLM
/// - [tools]: List of tools available to the LLM
/// - [conversation]: Initial conversation messages (used if getConversation is null)
/// - [getConversation]: Optional callback to get fresh conversation each iteration
///   (useful when conversation is persisted to DB and needs to be reloaded)
/// - [requestApproval]: Callback to request user approval for tool calls
/// - [executeToolCall]: Callback to execute approved tool calls (receives all at once)
/// - [onTextDelta]: Optional callback for streaming text deltas
/// - [onAssistantMessage]: Optional callback when assistant message is complete
/// - [onToolResultMessage]: Optional callback when tool results are ready
///
/// Returns [AgentLoopResult] indicating how the loop terminated:
/// - [AgentLoopCompleted]: No more tool calls, conversation complete
/// - [AgentLoopCancelled]: User cancelled tool approval
/// - [AgentLoopError]: An error occurred
///
/// Example:
/// ```dart
/// final result = await runAgentLoop(
///   llmStream: (conv, tools) => llmService.streamChat(conv, tools: tools),
///   tools: shellTools,
///   conversation: messages,
///   requestApproval: (toolCalls) => showApprovalDialog(toolCalls),
///   executeToolCall: (tcs) => shellService.executeAll(tcs),
///   onTextDelta: (delta) => updateUI(delta),
///   onAssistantMessage: (msg) => db.insert(msg),
///   onToolResultMessage: (msg) => db.insert(msg),
/// );
/// ```
Future<AgentLoopResult> runAgentLoop({
  required LlmStreamFunction llmStream,
  required List<Tool> tools,
  List<ChatMessage>? conversation,
  ConversationProvider? getConversation,
  required ApprovalFunction requestApproval,
  required ToolExecutionFunction executeToolCall,
  TextDeltaCallback? onTextDelta,
  MessageCallback? onAssistantMessage,
  ToolResultMessageCallback? onToolResultMessage,
  CancelToken? cancelToken,
}) async {
  // Work with a mutable copy if using in-memory conversation
  var messages = conversation != null
      ? List<ChatMessage>.from(conversation)
      : <ChatMessage>[];

  while (true) {
    // Check for cancellation at start of loop
    if (cancelToken?.isCancelled ?? false) {
      return const AgentLoopCancelled();
    }

    // Get fresh conversation if provider is available (e.g., from database)
    if (getConversation != null) {
      messages = await getConversation();
    }

    // Stream from LLM
    final streamResult = await _streamFromLlm(
      llmStream: llmStream,
      tools: tools,
      conversation: messages,
      onTextDelta: onTextDelta,
      cancelToken: cancelToken,
    );

    // If no tool calls, we're done
    if (streamResult.toolCalls.isEmpty) {
      // Notify about final text message if there is one
      if (streamResult.text.isNotEmpty && onAssistantMessage != null) {
        await onAssistantMessage(ChatMessage.assistant(streamResult.text));
      }
      return const AgentLoopCompleted();
    }

    // Convert to pending tool calls for approval
    final pendingCalls = <PendingToolCall>[];
    for (final tc in streamResult.toolCalls) {
      Map<String, dynamic> args;
      try {
        args = tc.function.arguments.isNotEmpty
            ? Map<String, dynamic>.from(jsonDecode(tc.function.arguments))
            : <String, dynamic>{};
      } catch (e) {
        // This is a data error, not an execution error, so maybe we should throw?
        // Or return AgentLoopError?
        // The user said "remove most of the places".
        // If we throw here, the caller handles it.
        throw Exception(
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

    // Build and save assistant message with tool use
    final assistantMessage = ChatMessage.toolUse(
      toolCalls: pendingCalls.map((p) => p.originalToolCall).toList(),
      content: streamResult.text,
    );
    // Add to in-memory conversation (will be overwritten if using getConversation)
    messages.add(assistantMessage);
    if (onAssistantMessage != null) {
      await onAssistantMessage(assistantMessage);
    }

    // Request approval
    final approved = await requestApproval(pendingCalls);

    // User cancelled
    if (approved == null) {
      return const AgentLoopCancelled();
    }

    // Get the approved ToolCalls with potentially updated arguments
    final approvedToolCalls = approved.map((p) {
      return ToolCall(
        id: p.originalToolCall.id,
        callType: p.originalToolCall.callType,
        function: FunctionCall(
          name: p.name,
          arguments: jsonEncode(p.arguments),
        ),
      );
    }).toList();

    // Execute all approved tool calls
    List<String> resultStrings;
    try {
      resultStrings = await executeToolCall(approvedToolCalls);
    } on AgentAbortException {
      return const AgentLoopCancelled();
    } catch (e) {
      // Return error as result so LLM can reason about it
      final errorResult = jsonEncode({
        'error': 'Tool execution failed.',
        'details': e.toString(),
      });
      resultStrings = List.filled(approvedToolCalls.length, errorResult);
    }

    // Build ToolCall results from execution
    final results = <ToolCall>[];
    for (var i = 0; i < approvedToolCalls.length; i++) {
      final toolCall = approvedToolCalls[i];
      final resultString = i < resultStrings.length
          ? resultStrings[i]
          : jsonEncode({
              'error': 'Missing result for tool call',
            });
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
      await onToolResultMessage(toolResultMessage,
          toolCallMessage: assistantMessage);
    }

    // Loop continues with updated conversation
  }
}

/// Internal result from streaming LLM response
class _StreamResult {
  final String text;
  final List<ToolCall> toolCalls;
  final UsageInfo? usage;

  _StreamResult({
    required this.text,
    required this.toolCalls,
    this.usage,
  });
}

/// Streams response from LLM and collects text/tool calls
Future<_StreamResult> _streamFromLlm({
  required LlmStreamFunction llmStream,
  required List<Tool> tools,
  required List<ChatMessage> conversation,
  TextDeltaCallback? onTextDelta,
  CancelToken? cancelToken,
}) async {
  final buffer = StringBuffer();
  final toolCallMap = <String, ToolCall>{};
  UsageInfo? usage;

  await for (final event in llmStream(
    conversation,
    tools,
    cancelToken: cancelToken,
  )) {
    switch (event) {
      case TextDeltaEvent(delta: final delta):
        buffer.write(delta);
        await onTextDelta?.call(delta);

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
              name: existing.function.name, // Name usually comes in first delta
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

      case CompletionEvent(response: final response):
        if (response.usage != null) {
          usage = response.usage;
          _log.info('LLM usage: $usage');
        }
        break;

      case ErrorEvent(error: final error):
        throw Exception(error.message);
    }
  }

  return _StreamResult(
    text: buffer.toString(),
    toolCalls: toolCallMap.values.toList(),
    usage: usage,
  );
}
