import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/providers/project_provider.dart';
import 'package:decamp/providers/session_provider.dart';
import 'package:decamp/providers/database_provider.dart';
import 'package:decamp/components/selectable_list_view.dart';

class SessionsHistoryPage extends ConsumerWidget {
  const SessionsHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProject = ref.watch(currentProjectProvider);
    final currentSessionId = ref.watch(currentSessionIdProvider);
    final theme = Theme.of(context);
    final sessionDao = ref.read(databaseProvider).sessionDao;
    final messageDao = ref.read(databaseProvider).messageDao;

    // Helper: Switch to another session if the current one is being removed
    Future<void> switchFromSession(SessionEntity session) async {
      final currentId = ref.read(currentSessionIdProvider);
      if (currentId != session.id) return;

      final sessions = await sessionDao.getSessionsByProject(session.projectId);
      final otherSessions = sessions
          .where((s) => s.id != session.id && !s.isArchived)
          .toList();

      if (otherSessions.isNotEmpty) {
        ref
            .read(currentSessionIdProvider.notifier)
            .select(otherSessions.first.id);
      } else {
        final newSessionId = await sessionDao.createSessionWithId(
          projectId: session.projectId,
        );
        ref.read(currentSessionIdProvider.notifier).select(newSessionId);
      }
    }

    return SelectableListView<SessionEntity>(
      title: '${currentProject?.name ?? 'Project'} Sessions',
      dao: sessionDao,
      activeData: ref.watch(currentProjectSessionsProvider),
      archivedData: ref.watch(archivedSessionsProvider),

      // Getters for entity properties
      getId: (s) => s.id,
      getName: (s) => s.description,

      getCreatedAt: (s) => s.createdAt,
      getUpdatedAt: (s) => s.updatedAt,

      // Selection
      isSelected: (s) => s.id == currentSessionId,
      onSelect: (session) {
        ref.read(currentSessionIdProvider.notifier).select(session.id);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Switched to: ${session.description}')),
        );
      },

      // Session-specific hooks
      beforeArchive: switchFromSession,
      beforeDelete: switchFromSession,
      cleanupOnDelete: (session) =>
          messageDao.deleteMessagesBySession(session.id),

      // Leading widget (arrow icon)
      leadingBuilder: (session, viewMode) {
        if (viewMode != SelectableViewMode.active) {
          return const SizedBox.shrink();
        }
        return Icon(
          Icons.arrow_back_ios,
          size: 16,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        );
      },

      // FAB
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final controller = ref.read(sessionControllerProvider);
          await controller.createNewSession();
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
        tooltip: 'New Session',
        child: const Icon(Icons.add_comment),
      ),
    );
  }
}
