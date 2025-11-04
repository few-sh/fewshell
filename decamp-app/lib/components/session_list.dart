import 'package:flutter/material.dart';
import 'package:hello_world/utils/date_formatter.dart';

class ChatSessionItem {
  final String id;
  final String description;
  final DateTime timestamp;

  ChatSessionItem({
    required this.id,
    required this.description,
    required this.timestamp,
  });
}

class SessionList extends StatelessWidget {
  final List<ChatSessionItem> sessions;
  final Function(ChatSessionItem)? onSessionTap;

  const SessionList({super.key, required this.sessions, this.onSessionTap});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No chat sessions yet',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new conversation to see it here',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final absoluteTime = DateFormatter.formatAbsoluteDateTime(
          session.timestamp,
        );
        final relativeTime = DateFormatter.formatRelativeTime(
          session.timestamp,
        );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.chat,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(
              session.description,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    absoluteTime,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    relativeTime,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (onSessionTap != null) {
                onSessionTap!(session);
              }
            },
          ),
        );
      },
    );
  }
}
