import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:decamp/providers/project_provider.dart';
import 'package:decamp/providers/session_provider.dart';
import 'package:decamp/utils/date_formatter.dart';

/// Sessions History Page
/// Displays all sessions for the current project
class SessionsHistoryPage extends ConsumerWidget {
  const SessionsHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProject = ref.watch(currentProjectProvider);
    final sessionsAsync = ref.watch(currentProjectSessionsProvider);
    final currentSessionId = ref.watch(currentSessionIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('${currentProject?.name ?? 'Project'} Sessions'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: sessionsAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No chat sessions yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a new conversation to see it here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
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
              final isCurrentSession = session.id == currentSessionId;

              // Calculate time difference between createdAt and updatedAt
              final timeDifference = session.updatedAt.difference(
                session.createdAt,
              );
              final showDateRange = timeDifference.inMinutes >= 5;

              // Check if both dates are on the same day
              final sameDay =
                  session.createdAt.year == session.updatedAt.year &&
                  session.createdAt.month == session.updatedAt.month &&
                  session.createdAt.day == session.updatedAt.day;

              // Format dates
              final createdTime = DateFormatter.formatAbsoluteDateTime(
                session.createdAt,
              );
              final updatedTime = DateFormatter.formatAbsoluteDateTime(
                session.updatedAt,
              );
              final relativeTime = DateFormatter.formatRelativeTime(
                session.updatedAt,
              );

              // Create date display based on conditions
              String dateDisplay;
              if (!showDateRange) {
                // Less than 5 minutes apart - show only updatedTime
                dateDisplay = updatedTime;
              } else if (sameDay) {
                // Same day and more than 5 minutes apart - show date with time range
                final createdTimeOnly = DateFormat(
                  'h:mm a',
                ).format(session.createdAt);
                final updatedTimeOnly = DateFormat(
                  'h:mm a',
                ).format(session.updatedAt);
                final dateOnly = DateFormat(
                  'MMM d, yyyy',
                ).format(session.createdAt);
                dateDisplay = '$dateOnly • $createdTimeOnly - $updatedTimeOnly';
              } else {
                // Different days - show full date range
                dateDisplay = '$createdTime - $updatedTime';
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: isCurrentSession ? 4 : 2,
                color: isCurrentSession
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: ListTile(
                  contentPadding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: 12,
                  ),
                  horizontalTitleGap: 8,
                  leading: Icon(
                    Icons.arrow_back_ios,
                    size: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  title: Text(
                    session.description,
                    style: TextStyle(
                      fontWeight: isCurrentSession
                          ? FontWeight.w600
                          : FontWeight.w500,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateDisplay,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          relativeTime,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isCurrentSession
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        if (isCurrentSession)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Active',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  onTap: isCurrentSession
                      ? () {
                          // Just navigate back for current session
                          Navigator.pop(context);
                        }
                      : () {
                          // Switch to the selected session
                          ref.read(currentSessionIdProvider.notifier).state =
                              session.id;

                          // Navigate back to chat
                          Navigator.pop(context);

                          // Show feedback
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Switched to: ${session.description}',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading sessions',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
