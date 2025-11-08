import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../database/database.dart';
import '../database/daos/session_dao.dart';
import 'database_provider.dart';
import 'project_provider.dart';
import 'message_provider.dart';

/// Provider for streaming sessions for a specific project (family provider)
final sessionsStreamProvider =
    StreamProvider.family<List<SessionEntity>, String>((ref, projectId) {
      final sessionDao = ref.watch(sessionDaoProvider);
      return sessionDao.watchSessionsByProject(projectId);
    });

/// Provider for sessions of the currently selected project
final currentProjectSessionsProvider = StreamProvider<List<SessionEntity>>((
  ref,
) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) {
    return Stream.value([]);
  }
  final sessionDao = ref.watch(sessionDaoProvider);
  return sessionDao.watchSessionsByProject(projectId);
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
        final sessionActions = _ref.read(sessionActionsProvider);
        sessionActions.createSession(projectId: projectId).then((newSessionId) {
          _ref.read(currentSessionIdProvider.notifier).state = newSessionId;
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

/// Provider for session actions (CRUD operations)
final sessionActionsProvider = Provider<SessionActions>((ref) {
  final sessionDao = ref.watch(sessionDaoProvider);
  return SessionActions(sessionDao, ref);
});

/// Class containing all session-related actions
class SessionActions {
  final SessionDao _sessionDao;
  final Ref _ref;

  SessionActions(this._sessionDao, this._ref);

  /// Create a new session for a project
  Future<String> createSession({
    required String projectId,
    String? description,
  }) async {
    final now = DateTime.now();
    final id = _generateSessionId();

    final companion = SessionEntityCompanion(
      id: drift.Value(id),
      projectId: drift.Value(projectId),
      description: drift.Value(description ?? 'New conversation'),
      timestamp: drift.Value(now),
      createdAt: drift.Value(now),
      updatedAt: drift.Value(now),
    );

    await _sessionDao.insertSession(companion);

    // Update project's last session date
    final projectActions = _ref.read(projectActionsProvider);
    await projectActions.updateLastSessionDate(projectId, now);

    return id;
  }

  /// Create a new session and switch to it
  /// Only creates if current session is not empty (has messages)
  /// Returns the new session ID if created, null if skipped
  Future<String?> createNewSessionAndSwitch({required String projectId}) async {
    // Check if current session has messages
    final currentSessionId = _ref.read(currentSessionIdProvider);
    if (currentSessionId != null) {
      final messageActions = _ref.read(messageActionsProvider);
      final messages = await messageActions.getMessagesBySession(
        currentSessionId,
      );

      // If current session is empty, don't create a new one
      if (messages.isEmpty) {
        return null;
      }
    }

    // Create new session
    final newSessionId = await createSession(projectId: projectId);

    // Switch to the new session
    _ref.read(currentSessionIdProvider.notifier).state = newSessionId;

    return newSessionId;
  }

  /// Update an existing session
  Future<void> updateSession({required String id, String? description}) async {
    final companion = SessionEntityCompanion(
      id: drift.Value(id),
      description: description != null
          ? drift.Value(description)
          : const drift.Value.absent(),
      updatedAt: drift.Value(DateTime.now()),
    );

    await _sessionDao.updateSession(companion);
  }

  /// Delete a session
  /// Also clears it from currentSessionIdProvider if it was selected
  Future<void> deleteSession(String id) async {
    await _sessionDao.deleteSession(id);

    // Clear selection if deleted session was selected
    final currentId = _ref.read(currentSessionIdProvider);
    if (currentId == id) {
      _ref.read(currentSessionIdProvider.notifier).state = null;
    }
  }

  /// Delete all sessions for a project
  Future<void> deleteSessionsByProject(String projectId) async {
    await _sessionDao.deleteSessionsByProject(projectId);

    // Clear selection if current session belonged to this project
    final currentSession = _ref.read(currentSessionProvider);
    if (currentSession?.projectId == projectId) {
      _ref.read(currentSessionIdProvider.notifier).state = null;
    }
  }

  /// Select a session as the current session
  void selectSession(String? id) {
    _ref.read(currentSessionIdProvider.notifier).state = id;
  }

  /// Get sessions for a project (non-reactive)
  Future<List<SessionEntity>> getSessionsByProject(String projectId) async {
    return await _sessionDao.getSessionsByProject(projectId);
  }

  /// Get a specific session by ID
  Future<SessionEntity?> getSession(String id) async {
    return await _sessionDao.getSession(id);
  }

  /// Get session count for a project
  Future<int> getSessionCount(String projectId) async {
    return await _sessionDao.getSessionCountByProject(projectId);
  }

  /// Generate a unique session ID
  String _generateSessionId() {
    return 'sess_${DateTime.now().millisecondsSinceEpoch}_${_randomString(8)}';
  }

  /// Generate a random string for ID uniqueness
  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      length,
      (index) => chars[(DateTime.now().microsecond + index) % chars.length],
    ).join();
  }
}
