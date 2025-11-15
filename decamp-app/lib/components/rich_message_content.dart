import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:intl/intl.dart';

/// Rich message content widget with extensible features
/// Supports: text selection, copy, collapsible sections, action buttons
class RichMessageContent extends StatelessWidget {
  final ChatMessage message;
  final bool isUser;
  final MarkdownStyleSheet? styleSheet;

  const RichMessageContent({
    super.key,
    required this.message,
    required this.isUser,
    this.styleSheet,
  });

  @override
  Widget build(BuildContext context) {
    // Extract metadata from customProperties
    final metadata = MessageMetadata.fromCustomProperties(
      message.customProperties ?? {},
    );

    Widget content;

    // Check if this is a collapsible message
    if (metadata.isCollapsible) {
      content = _buildCollapsibleContent(context, metadata);
    }
    // Check if this has action buttons
    else if (metadata.actions.isNotEmpty) {
      content = _buildInteractiveContent(context, metadata);
    }
    // Default: render markdown with selection support
    else {
      content = _buildMarkdownContent(context, metadata);
    }

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
    if (isUser) {
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

  Widget _buildMarkdownContent(BuildContext context, MessageMetadata metadata) {
    // Extract base text color from stylesheet
    final textColor =
        styleSheet?.p?.color ??
        Theme.of(context).textTheme.bodyLarge?.color ??
        Colors.white;

    final markdown = Markdown(
      data: message.text,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle(
          style: TextStyle(color: textColor),
          child: metadata.enableTextSelection
              ? SelectionArea(child: markdown)
              : markdown,
        ),
        if (metadata.showCopyButton) _buildCopyButton(context),
      ],
    );
  }

  Widget _buildCollapsibleContent(
    BuildContext context,
    MessageMetadata metadata,
  ) {
    return CollapsibleMessageSection(
      title: metadata.collapsibleTitle ?? 'Details',
      content: message.text,
      initiallyExpanded: metadata.initiallyExpanded,
      styleSheet: styleSheet,
    );
  }

  Widget _buildInteractiveContent(
    BuildContext context,
    MessageMetadata metadata,
  ) {
    // Extract base text color from stylesheet
    final textColor =
        styleSheet?.p?.color ??
        Theme.of(context).textTheme.bodyLarge?.color ??
        Colors.white;

    final markdown = Markdown(
      data: message.text,
      selectable: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      styleSheet: styleSheet,
      padding: EdgeInsets.zero,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle(
          style: TextStyle(color: textColor),
          child: metadata.enableTextSelection
              ? SelectionArea(child: markdown)
              : markdown,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: metadata.actions
              .map((action) => _buildActionButton(context, action))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, MessageAction action) {
    return FilledButton.tonal(
      onPressed: action.onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (action.icon != null) ...[
            Icon(action.icon, size: 16),
            const SizedBox(width: 6),
          ],
          Text(action.label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCopyButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () => _copyToClipboard(context),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.copy,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Copy',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

/// Collapsible message section
class CollapsibleMessageSection extends StatefulWidget {
  final String title;
  final String content;
  final bool initiallyExpanded;
  final MarkdownStyleSheet? styleSheet;

  const CollapsibleMessageSection({
    super.key,
    required this.title,
    required this.content,
    this.initiallyExpanded = false,
    this.styleSheet,
  });

  @override
  State<CollapsibleMessageSection> createState() =>
      _CollapsibleMessageSectionState();
}

class _CollapsibleMessageSectionState extends State<CollapsibleMessageSection>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _toggleExpansion,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(Icons.chevron_right, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: Padding(
            padding: const EdgeInsets.only(left: 28, top: 8),
            child: DefaultTextStyle(
              style: TextStyle(
                color: widget.styleSheet?.p?.color ?? Colors.white,
              ),
              child: SelectionArea(
                child: Markdown(
                  data: widget.content,
                  selectable: false,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  styleSheet: widget.styleSheet,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Message metadata extracted from customProperties
class MessageMetadata {
  final bool enableTextSelection;
  final bool showCopyButton;
  final bool isCollapsible;
  final String? collapsibleTitle;
  final bool initiallyExpanded;
  final List<MessageAction> actions;

  MessageMetadata({
    this.enableTextSelection = true,
    this.showCopyButton = false,
    this.isCollapsible = false,
    this.collapsibleTitle,
    this.initiallyExpanded = false,
    this.actions = const [],
  });

  factory MessageMetadata.fromCustomProperties(Map<String, dynamic> props) {
    return MessageMetadata(
      enableTextSelection: props['enableTextSelection'] as bool? ?? true,
      showCopyButton: props['showCopyButton'] as bool? ?? false,
      isCollapsible: props['isCollapsible'] as bool? ?? false,
      collapsibleTitle: props['collapsibleTitle'] as String?,
      initiallyExpanded: props['initiallyExpanded'] as bool? ?? false,
      actions:
          (props['actions'] as List?)
              ?.map((a) => MessageAction.fromMap(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Action button configuration
class MessageAction {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  MessageAction({required this.label, this.icon, required this.onPressed});

  factory MessageAction.fromMap(Map<String, dynamic> map) {
    return MessageAction(
      label: map['label'] as String,
      icon: map['icon'] as IconData?,
      onPressed: map['onPressed'] as VoidCallback,
    );
  }
}
