import 'package:flutter/material.dart';
import 'package:decamp/database/database.dart';
import 'package:decamp/components/rich_message_content.dart';
import 'package:decamp/models/message.dart';

/// Simple chat message list widget
/// Displays messages from database with streaming support
class ChatList extends StatelessWidget {
  final List<MessageEntity> messages;
  final bool isLoading;
  final String? streamingMessageId;
  final String streamingText;

  const ChatList({
    super.key,
    required this.messages,
    this.isLoading = false,
    this.streamingMessageId,
    this.streamingText = '',
  });

  @override
  Widget build(BuildContext context) {
    // Display all messages including tool results
    final displayMessages = messages;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: displayMessages.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (isLoading && index == 0) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Get message (adjust index if loading indicator is shown)
        final messageIndex = isLoading ? index - 1 : index;
        final msgEntity = displayMessages[messageIndex];

        // Convert to Message model for RichMessageContent
        final message = Message(
          id: msgEntity.id,
          sessionId: msgEntity.sessionId,
          userId: msgEntity.userId,
          userName: msgEntity.userName,
          content: msgEntity.content,
          timestamp: msgEntity.timestamp,
          createdAt: msgEntity.createdAt,
          imageUrl: msgEntity.imageUrl,
          metadata: msgEntity.metadata != null
              ? Map<String, dynamic>.from({}) // TODO: parse JSON
              : null,
        );

        // Check if this message is currently streaming
        final isStreaming = message.id == streamingMessageId;
        final displayText = isStreaming ? streamingText : message.content;
        final isUser = message.userId == 'user';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: RichMessageContent(
                message: message,
                displayText: displayText,
                isUser: isUser,
              ),
            ),
          ),
        );
      },
    );
  }
}
