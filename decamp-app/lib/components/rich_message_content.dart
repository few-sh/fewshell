import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:decamp/database/database.dart';
import 'package:decamp/database/tables/messages_table.dart';
import 'package:decamp/utils/tool_result_formatter.dart';

/// Rich message content widget
/// Renders message content as markdown with text selection support
class RichMessageContent extends StatelessWidget {
  final MessageEntity message;
  final String? displayText; // Override for streaming
  final bool isUser;
  final MarkdownStyleSheet? styleSheet;

  const RichMessageContent({
    super.key,
    required this.message,
    this.displayText,
    required this.isUser,
    this.styleSheet,
  });

  @override
  Widget build(BuildContext context) {
    // Use displayText override if provided (for streaming), otherwise format message content
    final text = displayText ?? _formatMessageContent();

    // Build markdown content
    final content = _buildMarkdownContent(context, text);

    // Wrap content with timestamp at the bottom
    final contentWithTimestamp = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.bottomRight,
          child: _buildTimestamp(context),
        ),
      ],
    );

    // Wrap user messages in a bubble container
    if (isUser &&
        (message.toolResultsJson == null || message.toolResultsJson!.isEmpty)) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(0),
          ),
        ),
        child: contentWithTimestamp,
      );
    }

    // AI messages: no bubble wrapper (flat appearance)
    return contentWithTimestamp;
  }

  Widget _buildTimestamp(BuildContext context) {
    final timestamp = message.createdAt;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    String formattedTime;
    if (messageDate == today) {
      // Today: show only time
      formattedTime = DateFormat('h:mm:ss a').format(timestamp);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Yesterday
      formattedTime = 'Yesterday ${DateFormat('h:mm:ss a').format(timestamp)}';
    } else if (now.difference(timestamp).inDays < 7) {
      // Within a week: show day and time
      formattedTime = DateFormat('EEE h:mm:ss a').format(timestamp);
    } else {
      // Older: show full date and time
      formattedTime = DateFormat('MMM d, h:mm:ss a').format(timestamp);
    }

    return Text(
      formattedTime,
      style: TextStyle(
        fontSize: 10,
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        fontWeight: FontWeight.w400,
      ),
    );
  }

  /// Format message content based on message type
  String _formatMessageContent() {
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

  Widget _buildMarkdownContent(BuildContext context, String text) {
    // Extract base text color from stylesheet
    final textColor =
        styleSheet?.p?.color ??
        Theme.of(context).textTheme.bodyLarge?.color ??
        Colors.white;

    final markdown = Markdown(
      data: text,
      selectable: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      styleSheet: styleSheet,
      padding: EdgeInsets.zero,
      onTapLink: (text, href, title) {
        if (href != null) {
          // TODO: Handle link taps (open in browser, etc.)
          debugPrint('Link tapped: $href');
        }
      },
    );

    return SelectionArea(
      child: DefaultTextStyle(
        style: TextStyle(color: textColor),
        child: markdown,
      ),
    );
  }
}
