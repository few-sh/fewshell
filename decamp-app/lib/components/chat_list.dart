import 'package:flutter/material.dart';
import 'package:decamp/database/database.dart';
import 'package:decamp/components/rich_message_content.dart';

/// Simple chat message list widget
/// Displays messages from database with streaming support
class ChatList extends StatefulWidget {
  final List<MessageEntity> messages;
  final bool isLoading;
  final String? streamingMessageId;
  final String streamingText;
  final Function(String messageId, String newContent)? onEditMessage;
  final Function(String messageId)? onResendMessage;
  final Function(String messageId)? onBranchSession;

  const ChatList({
    super.key,
    required this.messages,
    this.isLoading = false,
    this.streamingMessageId,
    this.streamingText = '',
    this.onEditMessage,
    this.onResendMessage,
    this.onBranchSession,
  });

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  final ScrollController _scrollController = ScrollController();

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

        // Check if this message is currently streaming
        final isStreaming = message.id == widget.streamingMessageId;
        // Only provide displayText when actually streaming
        final displayText = isStreaming ? widget.streamingText : null;
        final isUser = message.userId == 'user';

        return Column(
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
