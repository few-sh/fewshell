import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'database_provider.dart';
import 'project_provider.dart';

/// Provider for streaming sessions for a specific project (family provider)
final sessionsStreamProvider =
    StreamProvider.family<List<SessionEntity>, String>((ref, projectId) {
      final sessionDao = ref.watch(sessionDaoProvider);
      return sessionDao.watchSessionsByProject(projectId);
    });

/// Provider for sessions of the currently selected project
final currentProjectSessionsProvider = StreamProvider<List<SessionEntity>>(((
  ref,
) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) {
    return Stream.value([]);
  }
  final sessionDao = ref.watch(sessionDaoProvider);
  return sessionDao.watchNonArchivedSessionsByProject(projectId);
}));

/// Provider for archived sessions of the currently selected project
final archivedSessionsProvider = StreamProvider<List<SessionEntity>>((ref) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) {
    return Stream.value([]);
  }
  final sessionDao = ref.watch(sessionDaoProvider);
  return sessionDao.watchArchivedSessionsByProject(projectId);
});

/// Provider for archived sessions count
/// Watches the archived sessions stream and returns the count
final archivedSessionsCountProvider = Provider<int>((ref) {
  final archivedSessions = ref.watch(archivedSessionsProvider);
  return archivedSessions.maybeWhen(
    data: (sessions) => sessions.length,
    orElse: () => 0,
  );
});

/// StateProvider for the currently selected session ID
final currentSessionIdProvider = StateProvider<String?>((ref) => null);

/// Session manager that auto-creates/selects sessions
/// Watches project changes and sessions list to ensure a session is always selected
class SessionManager extends StateNotifier<void> {
  final Ref _ref;
  String? _lastProjectId;

  SessionManager(this._ref) : super(null) {
    // Listen to project ID changes
    _ref.listen(currentProjectIdProvider, (previous, next) {
      if (_lastProjectId != next) {
        _lastProjectId = next;
        _handleProjectChange(next);
      }
    });

    // Listen to sessions list changes
    _ref.listen(currentProjectSessionsProvider, (previous, next) {
      next.whenData((sessions) => _ensureSessionSelected(sessions));
    });
  }

  void _handleProjectChange(String? projectId) {
    if (projectId == null) {
      // Clear session when no project
      _ref.read(currentSessionIdProvider.notifier).state = null;
      return;
    }

    // Project changed - ensure we have a session
    final sessionsAsync = _ref.read(currentProjectSessionsProvider);
    sessionsAsync.whenData(_ensureSessionSelected);
  }

  void _ensureSessionSelected(List<SessionEntity> sessions) {
    final projectId = _ref.read(currentProjectIdProvider);
    final currentSessionId = _ref.read(currentSessionIdProvider);

    if (projectId == null) return;

    // Check if current session belongs to this project
    final needsSession =
        currentSessionId == null ||
        !sessions.any((s) => s.id == currentSessionId);

    if (needsSession) {
      if (sessions.isEmpty) {
        // Create new session
        final sessionDao = _ref.read(databaseProvider).sessionDao;
        final projectDao = _ref.read(databaseProvider).projectDao;
        
        sessionDao.createSessionWithId(projectId: projectId).then((newSessionId) {
          _ref.read(currentSessionIdProvider.notifier).state = newSessionId;
          // Update project's last session date
          projectDao.updateLastSessionDate(projectId, DateTime.now());
        });
      } else {
        // Select most recent session
        _ref.read(currentSessionIdProvider.notifier).state = sessions.first.id;
      }
    }
  }
}

/// Provider for the session manager
final sessionManagerProvider = StateNotifierProvider<SessionManager, void>((
  ref,
) {
  return SessionManager(ref);
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
