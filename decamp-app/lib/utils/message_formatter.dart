import 'package:decamp/database/database.dart';
import 'package:decamp/database/tables/messages_table.dart';
import 'package:decamp/utils/tool_result_formatter.dart';

/// Utility for formatting message content consistently
/// Used by both search and rendering to ensure offset alignment
class MessageFormatter {
  /// Format message content based on message type
  /// This is used both for searching and displaying to ensure consistency
  static String formatMessageContent(MessageEntity message) {
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
      // Get the first tool result
      final toolResult = message.toolResultsJson!.first;
      final toolName = toolResult.function.name;
      final resultContent = toolResult.function.arguments;

      // Format using the tool result formatter
      return ToolResultFormatter.format(
        toolName: toolName,
        result: resultContent,
      );
    }

    // For all other messages, use the content as-is
    return message.content;
  }
}
