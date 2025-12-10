import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:decamp/providers/project_provider.dart';
import 'package:decamp/providers/session_provider.dart';
import 'package:decamp/providers/database_provider.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/components/confirmation_dialog.dart';

/// Enum for view mode in sessions history
enum SessionsViewMode { active, archived }

/// Sessions History Page
/// Displays all sessions for the current project with archive functionality
class SessionsHistoryPage extends ConsumerStatefulWidget {
  const SessionsHistoryPage({super.key});

  @override
  ConsumerState<SessionsHistoryPage> createState() =>
      _SessionsHistoryPageState();
}

class _SessionsHistoryPageState extends ConsumerState<SessionsHistoryPage> {
  SessionsViewMode _viewMode = SessionsViewMode.active;

  @override
  Widget build(BuildContext context) {
    final currentProject = ref.watch(currentProjectProvider);
    final currentSessionId = ref.watch(currentSessionIdProvider);
    final archivedSessionsAsync = ref.watch(archivedSessionsProvider);
    final archivedCount = archivedSessionsAsync.maybeWhen(
      data: (sessions) => sessions.length,
      orElse: () => 0,
    );

    // Select appropriate provider based on view mode
    final sessionsAsync = _viewMode == SessionsViewMode.active
        ? ref.watch(currentProjectSessionsProvider)
        : ref.watch(archivedSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _viewMode == SessionsViewMode.active
              ? '${currentProject?.name ?? 'Project'} Sessions'
              : 'Archived Sessions',
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_viewMode == SessionsViewMode.active)
            // Archive button with badge
            archivedCount > 0
                ? Badge(
                    label: Text('$archivedCount'),
                    alignment: AlignmentDirectional.topStart,
                    child: IconButton(
                      icon: const Icon(Icons.archive),
                      tooltip: 'View archived sessions',
                      onPressed: () {
                        setState(() {
                          _viewMode = SessionsViewMode.archived;
                        });
                      },
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.archive),
                    tooltip: 'View archived sessions',
                    onPressed: () {
                      setState(() {
                        _viewMode = SessionsViewMode.archived;
                      });
                    },
                  )
          else
            // Back to active sessions button
            IconButton(
              icon: const Icon(Icons.unarchive),
              tooltip: 'View active sessions',
              onPressed: () {
                setState(() {
                  _viewMode = SessionsViewMode.active;
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Delete all archived button (only in archive view)
          if (_viewMode == SessionsViewMode.archived)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: sessionsAsync.when(
                data: (sessions) => sessions.isNotEmpty
                    ? ElevatedButton.icon(
                        onPressed: () => _showDeleteAllArchivedDialog(
                          context,
                          sessions.length,
                        ),
                        icon: const Icon(Icons.delete_forever),
                        label: Text('Delete All Archived (${sessions.length})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onError,
                        ),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
          // Sessions list
          Expanded(
            child: sessionsAsync.when(
              data: (sessions) =>
                  _buildSessionsList(context, sessions, currentSessionId),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorView(context, error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(
    BuildContext context,
    List<dynamic> sessions,
    String? currentSessionId,
  ) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _viewMode == SessionsViewMode.active
                  ? Icons.chat_bubble_outline
                  : Icons.archive_outlined,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _viewMode == SessionsViewMode.active
                  ? 'No chat sessions yet'
                  : 'No archived sessions',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _viewMode == SessionsViewMode.active
                  ? 'Start a new conversation to see it here'
                  : 'Archived sessions will appear here',
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
        return _buildSessionCard(
          context,
          session,
          session.id == currentSessionId,
        );
      },
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    dynamic session,
    bool isCurrentSession,
  ) {
    final theme = Theme.of(context);

    // Calculate time difference between createdAt and updatedAt
    final timeDifference = session.updatedAt.difference(session.createdAt);
    final showDateRange = timeDifference.inMinutes >= 5;

    // Check if both dates are on the same day
    final sameDay =
        session.createdAt.year == session.updatedAt.year &&
        session.createdAt.month == session.updatedAt.month &&
        session.createdAt.day == session.updatedAt.day;

    // Format dates
    final createdTime = DateFormatter.formatAbsoluteDateTime(session.createdAt);
    final updatedTime = DateFormatter.formatAbsoluteDateTime(session.updatedAt);
    final relativeTime = DateFormatter.formatRelativeTime(session.updatedAt);

    // Create date display based on conditions
    String dateDisplay;
    if (!showDateRange) {
      // Less than 5 minutes apart - show only updatedTime
      dateDisplay = updatedTime;
    } else if (sameDay) {
      // Same day and more than 5 minutes apart - show date with time range
      final createdTimeOnly = DateFormat('h:mm a').format(session.createdAt);
      final updatedTimeOnly = DateFormat('h:mm a').format(session.updatedAt);
      final dateOnly = DateFormat('MMM d, yyyy').format(session.createdAt);
      dateDisplay = '$dateOnly • $createdTimeOnly - $updatedTimeOnly';
    } else {
      // Different days - show full date range
      dateDisplay = '$createdTime - $updatedTime';
    }

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _viewMode == SessionsViewMode.active
              ? theme.colorScheme.secondary
              : theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _viewMode == SessionsViewMode.active
                  ? Icons.archive
                  : Icons.unarchive,
              color: theme.colorScheme.onSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              _viewMode == SessionsViewMode.active ? 'Archive' : 'Unarchive',
              style: TextStyle(
                color: theme.colorScheme.onSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (_viewMode == SessionsViewMode.active) {
          // Archive the session
          final sessionDao = ref.read(databaseProvider).sessionDao;

          // Check if this is the currently active session
          final currentSessionId = ref.read(currentSessionIdProvider);
          if (currentSessionId == session.id) {
            // Get all non-archived sessions for this project
            final sessions = await sessionDao.getSessionsByProject(
              session.projectId,
            );
            final otherSessions = sessions
                .where((s) => s.id != session.id && !s.isArchived)
                .toList();

            if (otherSessions.isNotEmpty) {
              // Switch to the most recent other session
              ref
                  .read(currentSessionIdProvider.notifier)
                  .select(otherSessions.first.id);
            } else {
              // No other sessions - create a new one
              final newSessionId = await sessionDao.createSessionWithId(
                projectId: session.projectId,
              );
              ref.read(currentSessionIdProvider.notifier).select(newSessionId);
            }
          }

          await sessionDao.archiveSession(session.id);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Archived: ${session.description}'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    final sessionDao = ref.read(databaseProvider).sessionDao;
                    sessionDao.unarchiveSession(session.id);
                  },
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          // Unarchive the session
          final sessionDao = ref.read(databaseProvider).sessionDao;
          await sessionDao.unarchiveSession(session.id);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Restored: ${session.description}'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
        return true;
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: isCurrentSession ? 4 : 2,
        color: isCurrentSession ? theme.colorScheme.primaryContainer : null,
        child: ListTile(
          contentPadding: const EdgeInsets.only(
            left: 16,
            right: 8, // Reduced right padding for trailing icons
            top: 12,
            bottom: 12,
          ),
          horizontalTitleGap: 8,
          leading: _viewMode == SessionsViewMode.active
              ? Icon(
                  Icons.arrow_back_ios,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                )
              : null,
          title: Text(
            session.description,
            style: TextStyle(
              fontWeight: isCurrentSession ? FontWeight.w600 : FontWeight.w500,
              fontSize: 16,
            ),
            maxLines: 4,
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
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  relativeTime,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isCurrentSession
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary,
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
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Star icon
              if (_viewMode == SessionsViewMode.active)
                IconButton(
                  icon: Icon(
                    session.isStarred ? Icons.star : Icons.star_border,
                    color: session.isStarred
                        ? Colors.amber
                        : theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                  ),
                  tooltip: session.isStarred ? 'Unstar' : 'Star',
                  onPressed: () => _toggleStar(session),
                ),
              // Menu icon
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz, // Ellipsis like chat
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
                tooltip: 'Session options',
                onSelected: (value) {
                  switch (value) {
                    case 'rename':
                      _showRenameSessionDialog(context, session);
                      break;
                    case 'archive':
                      _archiveSession(session);
                      break;
                    case 'unarchive':
                      _unarchiveSession(session);
                      break;
                    case 'delete':
                      _deleteSession(context, session);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 12),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  if (_viewMode == SessionsViewMode.active)
                    const PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          Icon(Icons.archive, size: 18),
                          SizedBox(width: 12),
                          Text('Archive'),
                        ],
                      ),
                    )
                  else
                    const PopupMenuItem(
                      value: 'unarchive',
                      child: Row(
                        children: [
                          Icon(Icons.unarchive, size: 18),
                          SizedBox(width: 12),
                          Text('Unarchive'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          onTap: _viewMode == SessionsViewMode.archived
              ? null // Archived sessions can't be tapped to open
              : isCurrentSession
              ? () {
                  // Just navigate back for current session
                  Navigator.pop(context);
                }
              : () {
                  // Switch to the selected session
                  ref
                      .read(currentSessionIdProvider.notifier)
                      .select(session.id);

                  // Navigate back to chat
                  Navigator.pop(context);

                  // Show feedback
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Switched to: ${session.description}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, Object error) {
    return Center(
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
    );
  }

  void _showDeleteAllArchivedDialog(BuildContext context, int count) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Delete All Archived Sessions?',
      content:
          'This will permanently delete $count archived ${count == 1 ? 'session' : 'sessions'}. This action cannot be undone.',
      confirmLabel: 'Delete All',
    );

    if (confirmed == true && context.mounted) {
      final projectId = ref.read(currentProjectIdProvider);
      if (projectId != null) {
        final sessionDao = ref.read(databaseProvider).sessionDao;
        final messageDao = ref.read(databaseProvider).messageDao;

        // Get all archived sessions first
        final archivedSessions = await sessionDao.getSessionsByProject(
          projectId,
        );
        final archivedSessionsFiltered = archivedSessions
            .where((s) => s.isArchived)
            .toList();

        // Delete messages for each archived session
        for (final session in archivedSessionsFiltered) {
          await messageDao.deleteMessagesBySession(session.id);
        }

        // Now delete the archived sessions themselves
        final deletedCount = await sessionDao.deleteArchivedSessionsByProject(
          projectId,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Deleted $deletedCount archived ${deletedCount == 1 ? 'session' : 'sessions'}',
              ),
              duration: const Duration(seconds: 2),
            ),
          );

          // Switch back to active view
          setState(() {
            _viewMode = SessionsViewMode.active;
          });
        }
      }
    }
  }

  Future<void> _toggleStar(SessionEntity session) async {
    final sessionDao = ref.read(databaseProvider).sessionDao;
    await sessionDao.toggleSessionStar(session.id, !session.isStarred);
  }

  Future<void> _archiveSession(dynamic session) async {
    // Check if this is the currently active session
    final currentSessionId = ref.read(currentSessionIdProvider);
    if (currentSessionId == session.id) {
      await _switchFromArchivedSession(session);
    }

    final sessionDao = ref.read(databaseProvider).sessionDao;
    await sessionDao.archiveSession(session.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Archived: ${session.description}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              sessionDao.unarchiveSession(session.id);
            },
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _unarchiveSession(dynamic session) async {
    final sessionDao = ref.read(databaseProvider).sessionDao;
    await sessionDao.unarchiveSession(session.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored: ${session.description}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _switchFromArchivedSession(dynamic session) async {
    final sessionDao = ref.read(databaseProvider).sessionDao;
    // Get all non-archived sessions for this project
    final sessions = await sessionDao.getSessionsByProject(session.projectId);
    final otherSessions = sessions
        .where((s) => s.id != session.id && !s.isArchived)
        .toList();

    if (otherSessions.isNotEmpty) {
      // Switch to the most recent other session
      ref
          .read(currentSessionIdProvider.notifier)
          .select(otherSessions.first.id);
    } else {
      // No other sessions - create a new one
      final newSessionId = await sessionDao.createSessionWithId(
        projectId: session.projectId,
      );
      ref.read(currentSessionIdProvider.notifier).select(newSessionId);
    }
  }

  Future<void> _deleteSession(BuildContext context, dynamic session) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Delete Session?',
      content:
          'Are you sure you want to delete "${session.description}"? This action cannot be undone.',
    );

    if (confirmed == true) {
      // If deleting current session, switch to another one
      final currentSessionId = ref.read(currentSessionIdProvider);
      if (currentSessionId == session.id) {
        await _switchFromArchivedSession(session);
      }

      final sessionDao = ref.read(databaseProvider).sessionDao;
      final messageDao = ref.read(databaseProvider).messageDao;

      // Delete messages first
      await messageDao.deleteMessagesBySession(session.id);
      // Delete session
      await sessionDao.deleteSession(session.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted: ${session.description}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showRenameSessionDialog(BuildContext context, dynamic session) {
    final controller = TextEditingController(text: session.description);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Session'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Session Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != session.description) {
                final sessionDao = ref.read(databaseProvider).sessionDao;
                await sessionDao.renameSession(session.id, newName);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}
