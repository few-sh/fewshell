import 'package:flutter/material.dart';
import 'package:decamp/database/database.dart';
import 'package:decamp/components/rich_message_content.dart';
import 'package:decamp/utils/search_utils.dart';

/// Simple chat message list widget
/// Displays messages from database with streaming support and search highlighting
class ChatList extends StatefulWidget {
  final List<MessageEntity> messages;
  final bool isLoading;
  final String? streamingMessageId;
  final String streamingText;
  final Function(String messageId, String newContent)? onEditMessage;
  final Function(String messageId)? onResendMessage;
  final Function(String messageId)? onBranchSession;
  final List<SearchMatch>? searchMatches;
  final String? currentMatchMessageId;

  const ChatList({
    super.key,
    required this.messages,
    this.isLoading = false,
    this.streamingMessageId,
    this.streamingText = '',
    this.onEditMessage,
    this.onResendMessage,
    this.onBranchSession,
    this.searchMatches,
    this.currentMatchMessageId,
  });

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};

  @override
  void didUpdateWidget(ChatList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Scroll when messages change or streaming updates
    if (widget.messages.length != oldWidget.messages.length ||
        widget.streamingText != oldWidget.streamingText) {
      WidgetsBinding.instance.endOfFrame.then((_) {
        if (mounted) _scrollToBottom();
      });
    }

    // Scroll to current match when it changes
    if (widget.currentMatchMessageId != null &&
        widget.currentMatchMessageId != oldWidget.currentMatchMessageId) {
      // Schedule scroll after next frame to ensure keys are attached
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToMatch(widget.currentMatchMessageId!);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    // In a reversed list, position 0 is the bottom
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollToMatch(String messageId) {
    final key = _messageKeys[messageId];
    if (key == null) {
      debugPrint('⚠️ No key found for message: $messageId');
      return;
    }

    if (key.currentContext == null) {
      debugPrint('⚠️ No context for message: $messageId');
      return;
    }

    final context = key.currentContext!;
    debugPrint('📍 Scrolling to message: $messageId');

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.5, // Center the message
    );
  }

  List<HighlightRange> _getHighlightsForMessage(String messageId) {
    if (widget.searchMatches == null) return [];

    final highlights = <HighlightRange>[];
    for (final match in widget.searchMatches!) {
      if (match.messageId == messageId) {
        highlights.add(
          HighlightRange(
            offset: match.matchOffset,
            length: match.matchLength,
            isActive: messageId == widget.currentMatchMessageId,
          ),
        );
      }
    }
    return highlights;
  }

  @override
  Widget build(BuildContext context) {
    // Reverse the list so newest messages are at index 0
    final reversedMessages = widget.messages.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      // Reverse the ListView so it naturally starts at the bottom
      reverse: true,
      padding: EdgeInsets.zero,
      itemCount: reversedMessages.length + (widget.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (widget.isLoading && index == 0) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Get message (adjust index if loading indicator is shown)
        final messageIndex = widget.isLoading ? index - 1 : index;
        final message = reversedMessages[messageIndex];

        // Ensure we have a key for this message
        _messageKeys.putIfAbsent(message.id, () => GlobalKey());

        // Check if this message is currently streaming
        final isStreaming = message.id == widget.streamingMessageId;
        // Only provide displayText when actually streaming
        final displayText = isStreaming ? widget.streamingText : null;
        final isUser = message.userId == 'user';

        // Get highlights for this message
        final highlights = _getHighlightsForMessage(message.id);

        return Column(
          key: _messageKeys[message.id],
          children: [
            if (messageIndex > 0)
              Divider(
                height: 8,
                thickness: 0.5,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.0),
              child: Align(
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: RichMessageContent(
                    message: message,
                    displayText: displayText,
                    isUser: isUser,
                    onEdit: widget.onEditMessage,
                    onResend: widget.onResendMessage,
                    onBranch: widget.onBranchSession,
                    highlights: highlights.isNotEmpty ? highlights : null,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
