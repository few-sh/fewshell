import 'package:agent_core/agent_core.dart';

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
          ToolResultFormatter.format(
            toolName: toolName,
            result: resultContent,
            originalToolCalls: message.toolCallsJson,
            toolCallId: toolResult.id,
          ),
        );
      }

      return buffer.toString();
    }

    // For all other messages, use the content as-is
    return message.content;
  }
}
