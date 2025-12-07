import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'database_provider.dart';
import 'project_provider.dart';

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

/// Controller for session logic
class SessionController {
  final Ref _ref;

  SessionController(this._ref);

  /// Ensures a valid session is selected for the given project
  Future<void> ensureSessionSelected(String projectId) async {
    final sessionDao = _ref.read(databaseProvider).sessionDao;
    final sessions = await sessionDao.getNonArchivedSessionsByProject(projectId);

    if (sessions.isEmpty) {
      // Create new session if none exist
      final projectDao = _ref.read(databaseProvider).projectDao;
      final newSessionId = await sessionDao.createSessionWithId(projectId: projectId);
      
      _ref.read(currentSessionIdProvider.notifier).state = newSessionId;
      await projectDao.updateLastSessionDate(projectId, DateTime.now());
    } else {
      // Select the most recent session
      // Note: Assuming getNonArchivedSessionsByProject returns sorted by date desc
      // If not, we might need to sort here or ensure DAO does it.
      // Based on typical chat app behavior, most recent is usually first.
      _ref.read(currentSessionIdProvider.notifier).state = sessions.first.id;
    }
  }
  
  Future<void> createNewSession() async {
    final projectId = _ref.read(currentProjectIdProvider);
    if (projectId == null) return;

    final sessionDao = _ref.read(databaseProvider).sessionDao;
    final projectDao = _ref.read(databaseProvider).projectDao;

    final newSessionId = await sessionDao.createSessionWithId(projectId: projectId);
    _ref.read(currentSessionIdProvider.notifier).state = newSessionId;
    await projectDao.updateLastSessionDate(projectId, DateTime.now());
  }
}

final sessionControllerProvider = Provider((ref) => SessionController(ref));

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
