import '../database/project_database.dart' show MessageEntity;
import '../database/tables/messages_table.dart' show MessageKind;
import 'tool_result_formatter.dart';

/// Utility for formatting message content consistently.
/// Used by both search and rendering to ensure offset alignment.
class MessageFormatter {
  /// Format message content based on message type.
  /// This is used both for searching and displaying to ensure consistency.
  static String formatMessageContent(MessageEntity message) {
    if (message.messageKind == MessageKind.toolUse &&
        message.toolCallsJson != null &&
        message.toolCallsJson!.isNotEmpty) {
      return ToolResultFormatter.formatToolUse(
        toolCalls: message.toolCallsJson!,
        textContent: message.content.isNotEmpty ? message.content : null,
      );
    }

    if (message.messageKind == MessageKind.toolResult &&
        message.toolResultsJson != null &&
        message.toolResultsJson!.isNotEmpty) {
      final buffer = StringBuffer();

      for (var i = 0; i < message.toolResultsJson!.length; i++) {
        final toolResult = message.toolResultsJson![i];
        final toolName = toolResult.function.name;
        final resultContent = toolResult.function.arguments;

        final originalToolCall =
            message.toolCallsJson != null && i < message.toolCallsJson!.length
            ? message.toolCallsJson![i]
            : null;

        if (i > 0) {
          buffer.writeln('\n');
        }

        buffer.write(
          ToolResultFormatter.format(
            toolName: toolName,
            result: resultContent,
            originalToolCall: originalToolCall,
            toolCallId: toolResult.id,
          ),
        );
      }

      return buffer.toString();
    }

    return message.content;
  }
}