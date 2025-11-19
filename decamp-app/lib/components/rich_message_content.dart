import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:decamp/database/database.dart';
import 'package:decamp/database/tables/messages_table.dart';
import 'package:decamp/utils/tool_result_formatter.dart';
import 'package:decamp/themes/terminal_theme.dart';
import 'package:decamp/components/expandable_code_block.dart';
import 'package:decamp/components/message_context_menu.dart';
import 'package:decamp/components/message_edit_field.dart';
import 'package:markdown/markdown.dart' as md;

/// Rich message content widget
/// Renders message content as markdown with text selection support
/// Supports inline editing with context menu
class RichMessageContent extends StatefulWidget {
  final MessageEntity message;
  final String? displayText; // Override for streaming
  final bool isUser;
  final MarkdownStyleSheet? styleSheet;
  final Function(String messageId, String newContent)? onEdit;
  final Function(String messageId)? onResend;
  final Function(String messageId)? onBranch;

  const RichMessageContent({
    super.key,
    required this.message,
    this.displayText,
    required this.isUser,
    this.styleSheet,
    this.onEdit,
    this.onResend,
    this.onBranch,
  });

  @override
  State<RichMessageContent> createState() => _RichMessageContentState();
}

class _RichMessageContentState extends State<RichMessageContent> {
  bool _isEditMode = false;

  void _enterEditMode() {
    setState(() {
      _isEditMode = true;
    });
  }

  void _exitEditMode() {
    setState(() {
      _isEditMode = false;
    });
  }

  void _handleSave(String newContent) {
    widget.onEdit?.call(widget.message.id, newContent);
    _exitEditMode();
  }

  void _handleResend() {
    widget.onResend?.call(widget.message.id);
  }

  void _handleBranch() {
    widget.onBranch?.call(widget.message.id);
  }

  @override
  Widget build(BuildContext context) {
    // Show edit field if in edit mode
    if (_isEditMode) {
      return MessageEditField(
        initialContent: widget.message.content,
        onSave: _handleSave,
        onCancel: _exitEditMode,
      );
    }

    // Use displayText override if provided (for streaming), otherwise format message content
    final text = widget.displayText ?? _formatMessageContent();

    // Build markdown content
    final content = _buildMarkdownContent(context, text);

    // Build timestamp with optional edit indicator
    final timestamp = _buildTimestamp(context);

    // Build controls row (timestamp + menu)
    final controls = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        timestamp,
        const SizedBox(width: 4),
        // Show context menu (always visible)
        MessageContextMenu(
          onEdit: _enterEditMode,
          onResend: _handleResend,
          onBranch: _handleBranch,
          messageContent: widget.message.content,
          showResend: widget.isUser, // Only show re-send for user messages
        ),
      ],
    );

    // Wrap user messages in a bubble container (content only, controls below)
    if (widget.isUser &&
        (widget.message.toolResultsJson == null ||
            widget.message.toolResultsJson!.isEmpty)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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
            child: content,
          ),
          const SizedBox(height: 4),
          controls,
        ],
      );
    }

    // AI messages: content with controls inline
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [content, const SizedBox(height: 4), controls],
    );
  }

  Widget _buildTimestamp(BuildContext context) {
    final timestamp = widget.message.createdAt;
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

    // Add edit indicator if message was edited
    final editedIndicator = widget.message.editedAt != null ? ' (edited)' : '';

    return Text(
      formattedTime + editedIndicator,
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
    if (widget.message.messageKind == MessageKind.toolUse &&
        widget.message.toolCallsJson != null &&
        widget.message.toolCallsJson!.isNotEmpty) {
      return ToolResultFormatter.formatToolUse(
        toolCalls: widget.message.toolCallsJson!,
        textContent: widget.message.content.isNotEmpty
            ? widget.message.content
            : null,
      );
    }

    // For tool result messages, use the formatter
    if (widget.message.messageKind == MessageKind.toolResult &&
        widget.message.toolResultsJson != null &&
        widget.message.toolResultsJson!.isNotEmpty) {
      // Get the first tool result
      final toolResult = widget.message.toolResultsJson!.first;
      final toolName = toolResult.function.name;
      final resultContent = toolResult.function.arguments;

      // Format using the tool result formatter
      return ToolResultFormatter.format(
        toolName: toolName,
        result: resultContent,
      );
    }

    // For all other messages, use the content as-is
    return widget.message.content;
  }

  Widget _buildMarkdownContent(BuildContext context, String text) {
    // Get terminal theme for code blocks
    final terminalTheme =
        Theme.of(context).extension<TerminalTheme>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? TerminalTheme.dark
            : TerminalTheme.light);

    // Extract base text color from stylesheet
    final textColor =
        widget.styleSheet?.p?.color ??
        Theme.of(context).textTheme.bodyLarge?.color ??
        Colors.white;

    // Track code block index for unique hero tags
    int codeBlockIndex = 0;

    // Create enhanced stylesheet with terminal theme for code blocks
    final enhancedStyleSheet =
        (widget.styleSheet ?? MarkdownStyleSheet.fromTheme(Theme.of(context)))
            .copyWith(
              code: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: terminalTheme.textColor,
                backgroundColor: terminalTheme.backgroundColor,
              ),
              codeblockDecoration: BoxDecoration(
                color: terminalTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: terminalTheme.borderColor, width: 1),
              ),
              codeblockPadding: const EdgeInsets.all(12),
            );

    final markdown = Markdown(
      data: text,
      selectable: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      styleSheet: enhancedStyleSheet,
      padding: EdgeInsets.zero,
      builders: {
        'code': ExpandableCodeBlockBuilder(
          terminalTheme: terminalTheme,
          messageId: widget.message.id,
          getCodeBlockIndex: () => codeBlockIndex++,
        ),
      },
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

/// Custom markdown builder for expandable code blocks
class ExpandableCodeBlockBuilder extends MarkdownElementBuilder {
  final TerminalTheme terminalTheme;
  final String messageId;
  final int Function() getCodeBlockIndex;

  ExpandableCodeBlockBuilder({
    required this.terminalTheme,
    required this.messageId,
    required this.getCodeBlockIndex,
  });

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent;
    final language =
        element.attributes['class']?.replaceFirst('language-', '') ?? '';
    final index = getCodeBlockIndex();
    final heroTag = 'code_block_${messageId}_$index';

    return ExpandableCodeBlock(
      code: code,
      language: language,
      heroTag: heroTag,
      terminalTheme: terminalTheme,
    );
  }
}
