import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'database_provider.dart';
import 'project_selection_provider.dart';

/// Provider for sessions of the currently selected project
final currentProjectSessionsProvider = StreamProvider<List<SessionEntity>>(((
  ref,
) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) {
    return Stream.value([]);
  }
  final sessionDao = ref.watch(databaseProvider).sessionDao;
  return sessionDao.watchNonArchivedSessionsByProject(projectId);
}));

/// Provider for archived sessions of the currently selected project
final archivedSessionsProvider = StreamProvider<List<SessionEntity>>((ref) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) {
    return Stream.value([]);
  }
  final sessionDao = ref.watch(databaseProvider).sessionDao;
  return sessionDao.watchArchivedSessionsByProject(projectId);
});

/// StateProvider for the currently selected session ID
final currentSessionIdProvider = StateProvider<String?>((ref) => null);

/// Session auto-selector that runs after build
/// Watches project and sessions to ensure a valid session is always selected
final sessionAutoSelectorProvider = Provider<void>((ref) {
  void handleSelection() {
    final projectId = ref.read(currentProjectIdProvider);
    final sessionsAsync = ref.read(currentProjectSessionsProvider);

    if (projectId == null) {
      if (ref.read(currentSessionIdProvider) != null) {
        ref.read(currentSessionIdProvider.notifier).state = null;
      }
      return;
    }

    final sessions = sessionsAsync.when(
      data: (sessions) => sessions,
      loading: () => null,
      error: (_, _) => null,
    );

    if (sessions == null) return;

    final currentSessionId = ref.read(currentSessionIdProvider);

    // Check if we need to select a session
    final needsSession =
        currentSessionId == null ||
        !sessions.any((s) => s.id == currentSessionId);

    if (!needsSession) return;

    if (sessions.isEmpty) {
      // Create new session
      final sessionDao = ref.read(databaseProvider).sessionDao;
      final projectDao = ref.read(databaseProvider).projectDao;

      sessionDao.createSessionWithId(projectId: projectId).then((newSessionId) {
        ref.read(currentSessionIdProvider.notifier).state = newSessionId;
        projectDao.updateLastSessionDate(projectId, DateTime.now());
      });
    } else {
      // Select most recent session
      ref.read(currentSessionIdProvider.notifier).state = sessions.first.id;
    }
  }

  ref.listen(currentProjectIdProvider, (_, _) => handleSelection());
  ref.listen(currentProjectSessionsProvider, (_, _) => handleSelection());

  // Run initially
  Future.microtask(handleSelection);
});

/// Provider for the currently selected session
/// Returns null if no session is selected or session doesn't exist
final currentSessionProvider = Provider<SessionEntity?>((ref) {
  final sessionId = ref.watch(currentSessionIdProvider);
  if (sessionId == null) return null;

  final sessionsAsync = ref.watch(currentProjectSessionsProvider);
  return sessionsAsync.whenData((sessions) {
    try {
      return sessions.firstWhere((s) => s.id == sessionId);
    } catch (e) {
      return null;
    }
  }).value;
});
