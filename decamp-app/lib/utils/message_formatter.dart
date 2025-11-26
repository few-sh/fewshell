import 'dart:convert';

import 'package:agent_core/agent_core.dart' as core;
import 'package:decamp/database/database.dart';
import 'package:decamp/database/tables/messages_table.dart';
import 'package:decamp/utils/tool_result_formatter.dart';
import 'package:llm_dart/llm_dart.dart';

/// Utility for formatting message content consistently
/// Used by both search and rendering to ensure offset alignment
class MessageFormatter {
  /// Format message content based on message type
  /// This is used both for searching and displaying to ensure consistency
  /// Accepts either MessageEntity (Drift) or Message (agent-core)
  static String formatMessageContent(dynamic message) {
    if (message is MessageEntity) {
      return _formatMessageEntity(message);
    } else if (message is core.Message) {
      return _formatCoreMessage(message);
    } else {
      throw ArgumentError(
        'Expected MessageEntity or Message, got ${message.runtimeType}',
      );
    }
  }

  /// Format a MessageEntity (from Drift database)
  static String _formatMessageEntity(MessageEntity message) {
    // For tool use messages, format the tool calls
    if (message.messageKind == MessageKind.toolUse &&
        message.toolCallsJson != null &&
        message.toolCallsJson!.isNotEmpty) {
      return ToolResultFormatter.formatToolUse(
        toolCalls: message.toolCallsJson!,
        textContent: message.content.isNotEmpty ? message.content : null,
      );
    }

    // For tool result messages, use the formatter
    if (message.messageKind == MessageKind.toolResult &&
        message.toolResultsJson != null &&
        message.toolResultsJson!.isNotEmpty) {
      final buffer = StringBuffer();

      // Format all tool results
      for (var i = 0; i < message.toolResultsJson!.length; i++) {
        final toolResult = message.toolResultsJson![i];
        final toolName = toolResult.function.name;
        final resultContent = toolResult.function.arguments;

        // Add separator between multiple results
        if (i > 0) {
          buffer.writeln('\n');
        }

        // Format using the tool result formatter
        buffer.write(
          ToolResultFormatter.format(toolName: toolName, result: resultContent),
        );
      }

      return buffer.toString();
    }

    // For all other messages, use the content as-is
    return message.content;
  }

  /// Format a Message (from agent-core)
  static String _formatCoreMessage(core.Message message) {
    // For tool use messages, format the tool calls
    if (message.messageKind == core.MessageKind.toolUse &&
        message.toolCallsJson != null &&
        message.toolCallsJson!.isNotEmpty) {
      final toolCalls = _parseToolCalls(message.toolCallsJson!);
      return ToolResultFormatter.formatToolUse(
        toolCalls: toolCalls,
        textContent: message.content.isNotEmpty ? message.content : null,
      );
    }

    // For tool result messages, use the formatter
    if (message.messageKind == core.MessageKind.toolResult &&
        message.toolResultsJson != null &&
        message.toolResultsJson!.isNotEmpty) {
      final toolResults = _parseToolCalls(message.toolResultsJson!);
      final buffer = StringBuffer();

      // Format all tool results
      for (var i = 0; i < toolResults.length; i++) {
        final toolResult = toolResults[i];
        final toolName = toolResult.function.name;
        final resultContent = toolResult.function.arguments;

        // Add separator between multiple results
        if (i > 0) {
          buffer.writeln('\n');
        }

        // Format using the tool result formatter
        buffer.write(
          ToolResultFormatter.format(toolName: toolName, result: resultContent),
        );
      }

      return buffer.toString();
    }

    // For all other messages, use the content as-is
    return message.content;
  }

  /// Parse tool calls from JSON string
  static List<ToolCall> _parseToolCalls(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      final func = map['function'] as Map<String, dynamic>;
      return ToolCall(
        id: map['id'] as String,
        callType: map['type'] as String? ?? 'function',
        function: FunctionCall(
          name: func['name'] as String,
          arguments: func['arguments'] as String,
        ),
      );
    }).toList();
  }
}
