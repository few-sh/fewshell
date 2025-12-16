import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:intl/intl.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/utils/message_formatter.dart';
import 'package:decamp/themes/terminal_theme.dart';
import 'package:decamp/components/expandable_code_block.dart';
import 'package:decamp/components/message_context_menu.dart';
import 'package:decamp/components/message_edit_field.dart';
import 'package:decamp/utils/search_utils.dart';
import 'package:decamp/utils/highlight_injector.dart';
import 'package:decamp/providers/chat_controller_provider.dart';
import 'package:decamp/services/sync_service.dart';
import 'package:decamp/components/multi_command_approval_overlay.dart';
import 'package:decamp/providers/session_provider.dart';
import 'package:logging/logging.dart';

/// Rich message content widget
/// Renders message content as markdown with text selection support
/// Supports inline editing with context menu and search highlighting
class RichMessageContent extends ConsumerStatefulWidget {
  final MessageEntity message;
  final Stream<MessageEntity>? messageStream;
  final bool isUser;
  final List<HighlightRange>?
  highlights; // Pre-computed highlights for this message
  final int?
  currentMatchIndex; // Index of currently active match (for animation)

  const RichMessageContent({
    super.key,
    required this.message,
    this.messageStream,
    required this.isUser,
    this.highlights,
    this.currentMatchIndex,
  });

  @override
  ConsumerState<RichMessageContent> createState() => _RichMessageContentState();
}

class _RichMessageContentState extends ConsumerState<RichMessageContent> {
  static final _log = Logger('RichMessageContent');
  bool _isEditMode = false;
  String _streamedContent = '';
  StreamSubscription? _messageSub;

  @override
  void initState() {
    super.initState();
    _setupStreams();
  }

  @override
  void didUpdateWidget(RichMessageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messageStream != oldWidget.messageStream) {
      _disposeStreams();
      _setupStreams();
    }
  }

  @override
  void dispose() {
    _disposeStreams();
    super.dispose();
  }

  void _setupStreams() {
    if (widget.messageStream != null) {
      _streamedContent = '';
      _messageSub = widget.messageStream!.listen((message) {
        if (mounted && message.id == widget.message.id) {
          setState(() {
            _streamedContent = message.content;
          });
        }
      });
    }
  }

  void _disposeStreams() {
    _messageSub?.cancel();
    _messageSub = null;
  }

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

  Future<void> _handleSave(String newContent) async {
    _log.info('✏️ Editing message: ${widget.message.id}');

    final controller = ref.read(
      chatControllerProvider(widget.message.sessionId).notifier,
    );

    // Get sync channel
    final syncChannel = ref.read(syncServiceProvider).projectChannel;

    await controller.editMessage(
      messageId: widget.message.id,
      newContent: newContent,
      sessionId: widget.message.sessionId,
      requestApproval: (actions) {
        if (!mounted) return Future.value(null);
        return MultiCommandApprovalOverlay.show(context, actions);
      },
      syncChannel: syncChannel,
    );
    _exitEditMode();
  }

  Future<void> _handleResend() async {
    _log.info('🔄 Resending message: ${widget.message.id}');

    final controller = ref.read(
      chatControllerProvider(widget.message.sessionId).notifier,
    );

    // Get sync channel
    final syncChannel = ref.read(syncServiceProvider).projectChannel;

    await controller.resendMessage(
      messageId: widget.message.id,
      sessionId: widget.message.sessionId,
      requestApproval: (actions) {
        if (!mounted) return Future.value(null);
        return MultiCommandApprovalOverlay.show(context, actions);
      },
      syncChannel: syncChannel,
    );
  }

  Future<void> _handleBranch() async {
    _log.info('🌿 Branching session at message: ${widget.message.id}');

    final controller = ref.read(
      chatControllerProvider(widget.message.sessionId).notifier,
    );

    final newSessionId = await controller.branchSession(
      messageId: widget.message.id,
      sessionId: widget.message.sessionId,
    );

    // Switch to the new session
    ref.read(currentSessionIdProvider.notifier).select(newSessionId);

    _log.info('✅ Switched to new session: $newSessionId');
  }

  Future<void> _handleDelete() async {
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text(
          'Are you sure you want to delete this message? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _log.info('🗑️ Deleting message: ${widget.message.id}');

    final controller = ref.read(
      chatControllerProvider(widget.message.sessionId).notifier,
    );

    await controller.deleteMessage(widget.message.id);
  }

  /// Get pre-computed highlights for this message
  List<HighlightRange> _getHighlights() {
    return widget.highlights ?? [];
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

    // Use streamed content if available, otherwise format message content
    var text = widget.messageStream != null
        ? _streamedContent
        : MessageFormatter.formatMessageContent(widget.message);

    // Build markdown content
    final content = _buildMarkdownContent(
      context,
      text,
    ); // Build timestamp with optional edit indicator
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
          onDelete: _handleDelete,
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

    final userName = widget.message.userName;

    final baseStyle = TextStyle(
      fontSize: 10,
      color: Theme.of(
        context,
      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      fontWeight: FontWeight.w400,
    );

    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: '\n',
            style: TextStyle(
              fontSize: 1,
              color: Colors.transparent,
              height: 0.1,
            ),
          ),
          TextSpan(
            text: userName,
            style: baseStyle.copyWith(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: ' | $formattedTime$editedIndicator', style: baseStyle),
        ],
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

    // Get highlight colors from theme
    final colorScheme = Theme.of(context).colorScheme;
    final activeHighlightColor = colorScheme.tertiary;
    final inactiveHighlightColor = colorScheme.tertiaryContainer.withValues(
      alpha: 0.5,
    );

    // Create custom component for rendering highlights
    final highlightComponent = SearchHighlightComponent(
      activeMatchIndex: widget.currentMatchIndex,
      activeColor: activeHighlightColor,
      inactiveColor: inactiveHighlightColor,
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

        // Extract highlights from code and clean it
        final codeData = HighlightInjector.extractFromCode(code);

        return ExpandableCodeBlock(
          code: codeData.code,
          language: language,
          heroTag: heroTag,
          terminalTheme: terminalTheme,
          highlights: codeData.highlights,
          activeColor: activeHighlightColor,
          inactiveColor: inactiveHighlightColor,
        );
      },
    );

    return markdown;
  }
}
