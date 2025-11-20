import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:intl/intl.dart';
import 'package:decamp/database/database.dart';
import 'package:decamp/utils/message_formatter.dart';
import 'package:decamp/themes/terminal_theme.dart';
import 'package:decamp/components/expandable_code_block.dart';
import 'package:decamp/components/message_context_menu.dart';
import 'package:decamp/components/message_edit_field.dart';
import 'package:decamp/utils/search_utils.dart';
import 'package:decamp/utils/highlight_injector.dart';

/// Rich message content widget
/// Renders message content as markdown with text selection support
/// Supports inline editing with context menu and search highlighting
class RichMessageContent extends StatefulWidget {
  final MessageEntity message;
  final String? displayText; // Override for streaming
  final bool isUser;
  final Function(String messageId, String newContent)? onEdit;
  final Function(String messageId)? onResend;
  final Function(String messageId)? onBranch;
  final List<SearchMatch>? searchMatches; // All search matches
  final int? currentMatchIndex; // Index of currently active match

  const RichMessageContent({
    super.key,
    required this.message,
    this.displayText,
    required this.isUser,
    this.onEdit,
    this.onResend,
    this.onBranch,
    this.searchMatches,
    this.currentMatchIndex,
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

  /// Calculate highlights for this message from search matches
  List<HighlightRange> _getHighlights() {
    if (widget.searchMatches == null || widget.searchMatches!.isEmpty) {
      return [];
    }

    return widget.searchMatches!
        .asMap()
        .entries
        .where((entry) => entry.value.messageId == widget.message.id)
        .map((entry) {
          final i = entry.key;
          final match = entry.value;
          return HighlightRange(
            offset: match.matchOffset,
            length: match.matchLength,
            isActive: i == widget.currentMatchIndex,
            matchIndex: i,
          );
        })
        .toList();
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
    final text =
        widget.displayText ??
        MessageFormatter.formatMessageContent(widget.message);

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

  Widget _buildMarkdownContent(BuildContext context, String text) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;

    // Get terminal theme for code blocks
    final terminalTheme =
        Theme.of(context).extension<TerminalTheme>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? TerminalTheme.dark
            : TerminalTheme.light);

    // Track code block index for unique hero tags
    int codeBlockIndex = 0;

    // Calculate highlights for this message
    final highlights = _getHighlights();

    // Pre-process text to inject highlight markers
    final processedText = HighlightInjector.injectMarkers(text, highlights);

    // Create custom component for rendering highlights
    final highlightComponent = SearchHighlightComponent(
      activeMatchIndex: widget.currentMatchIndex,
      activeColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
      inactiveColor: Theme.of(
        context,
      ).colorScheme.secondary.withValues(alpha: 0.2),
    );

    Widget markdown = GptMarkdown(
      processedText,
      style: TextStyle(color: textColor),
      inlineComponents: [
        highlightComponent,
        ...MarkdownComponent.inlineComponents,
      ],
      codeBuilder: (context, language, code, closed) {
        final index = codeBlockIndex++;
        final heroTag = 'code_block_${widget.message.id}_$index';

        return ExpandableCodeBlock(
          code: code,
          language: language,
          heroTag: heroTag,
          terminalTheme: terminalTheme,
        );
      },
    );

    return SelectionArea(child: markdown);
  }
}
