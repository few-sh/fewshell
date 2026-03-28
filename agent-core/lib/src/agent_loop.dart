import 'dart:convert';

import 'package:llm_dart/llm_dart.dart';
import 'package:logging/logging.dart';

import 'database/project_database.dart';
import 'database/tables/messages_table.dart';
import 'extensions/chat_message_extensions.dart';
import 'services/conversation_summarizer.dart';
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
/// - [getConversation]: Callback to get fresh conversation each iteration
///   (useful when conversation is persisted to DB and needs to be reloaded)
/// - [requestApproval]: Callback to request user approval for tool calls
/// - [executeToolCall]: Callback to execute approved tool calls (receives all at once)
/// - [onTextDelta]: Callback for streaming text deltas
/// - [onAssistantMessage]: Callback when assistant message is complete
/// - [onToolResultMessage]: Callback when tool results are ready
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
///   getConversation: () => db.getConversation(),
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
  required ConversationProvider getConversation,
  required ApprovalFunction requestApproval,
  required ToolExecutionFunction executeToolCall,
  required TextDeltaCallback onTextDelta,
  required MessageCallback onAssistantMessage,
  required ToolResultMessageCallback onToolResultMessage,
  required CancelToken cancelToken,
}) async {
  while (true) {
    // Check for cancellation at start of loop
    if (cancelToken.isCancelled) {
      return const AgentLoopCancelled();
    }

    // Build conversation from DB entities.
    final dbMessages = await getConversation();

    if (dbMessages.isEmpty) {
      return const AgentLoopError(
          "Something is wrong: can't find conversation history. No messages found in database.");
    }

    // If the persisted tail is a tool-use message, resume from approval/execution.
    final lastMessage = dbMessages.last;
    if (lastMessage.messageKind == MessageKind.toolUse) {
      final approved = await requestApproval(
          _toPendingToolCalls(lastMessage.toolCallsJson ?? []));

      // User cancelled
      if (approved == null) {
        return const AgentLoopCancelled();
      }

      try {
        await _executeAndPersistToolResults(
          approved: approved,
          toolUseMessage: lastMessage,
          executeToolCall: executeToolCall,
          onToolResultMessage: onToolResultMessage,
        );
      } on AgentAbortException {
        return const AgentLoopCancelled();
      }

      // Tool result persisted; continue so next loop can call LLM with fresh context.
      continue;
    }

    final messages = _buildConversationHistory(dbMessages);

    // Stream from LLM
    final streamResult = await _streamFromLlm(
      llmStream: llmStream,
      tools: tools,
      conversation: messages,
      onTextDelta: onTextDelta,
      cancelToken: cancelToken,
    );

    final assistantMessage = streamResult.toolCalls.isNotEmpty
        ? ChatMessage.toolUse(
            toolCalls: streamResult.toolCalls,
            content: streamResult.text,
          )
        : ChatMessage.assistant(streamResult.text);

    // Persist at the end of the iteration so we can resume from persisted tool use.
    await onAssistantMessage(assistantMessage);

    if (streamResult.toolCalls.isEmpty) {
      return const AgentLoopCompleted();
    }

    // Loop continues: next iteration sees the persisted tool-use and executes it.
  }
}

List<PendingToolCall> _toPendingToolCalls(List<ToolCall> toolCalls) {
  final pendingCalls = <PendingToolCall>[];
  for (final tc in toolCalls) {
    Map<String, dynamic> args;
    try {
      args = tc.function.arguments.isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(tc.function.arguments))
          : <String, dynamic>{};
    } catch (e) {
      throw Exception(
        'Failed to parse JSON arguments for tool ${tc.function.name}: $e',
      );
    }

    pendingCalls.add(
      PendingToolCall(
        arguments: args,
        originalToolCall: tc,
      ),
    );
  }
  return pendingCalls;
}

Future<void> _executeAndPersistToolResults({
  required List<PendingToolCall> approved,
  required MessageEntity toolUseMessage,
  required ToolExecutionFunction executeToolCall,
  required ToolResultMessageCallback onToolResultMessage,
}) async {
  // Build approved tool calls and assistant message from approved list
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

  final toolCallMessage = ChatMessage.toolUse(
    toolCalls: approved.map((p) => p.originalToolCall).toList(),
    content: toolUseMessage.content,
  );

  // Execute all approved tool calls
  List<String> resultStrings;
  try {
    resultStrings = await executeToolCall(toolUseMessage, approvedToolCalls);
  } on AgentAbortException {
    rethrow;
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

  await onToolResultMessage(toolResultMessage,
      toolCallMessage: toolCallMessage);
}

List<ChatMessage> _buildConversationHistory(List<MessageEntity> dbMessages) {
  final conversation = <ChatMessage>[];

  for (final messageEntity in dbMessages) {
    // Skip streaming placeholders and non-LLM-visible/system-only messages.
    if (messageEntity.isStreaming ||
        !messageEntity.isVisibleToLlm ||
        messageEntity.messageKind == MessageKind.notification) {
      continue;
    }

    final chatMessages = messageEntity.toChatMessage();
    for (final chatMessage in chatMessages) {
      if (messageEntity.messageKind == MessageKind.conversationSummary &&
          chatMessage.role == ChatRole.user) {
        conversation.add(
          ChatMessage.user('$conversationSummaryPrefix${chatMessage.content}'),
        );
      } else {
        conversation.add(chatMessage);
      }
    }
  }

  if (conversation.isNotEmpty) {
    for (int i = conversation.length - 1; i >= 0; i--) {
      if (conversation[i].messageType is TextMessage) {
        // This extension is consumed by Anthropic and ignored by other providers.
        conversation[i] = conversation[i].withExtension(
          'anthropic',
          {
            'contentBlocks': [
              {
                'type': 'text',
                'text': '',
                'cache_control': {'type': 'ephemeral', 'ttl': '5m'},
              },
            ],
          },
        );
        break;
      }
    }
  }

  return conversation;
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
