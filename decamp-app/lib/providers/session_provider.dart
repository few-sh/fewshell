import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Circular import for provider access
import 'providers.dart';

/// StateNotifier for the currently selected session ID
class SelectedSessionNotifier extends StateNotifier<String?> {
  final SharedPreferences _prefs;
  final Ref _ref;

  SelectedSessionNotifier(this._prefs, this._ref) : super(null);

  Future<void> select(String? sessionId) async {
    state = sessionId;
    final projectId = _ref.read(currentProjectIdProvider);
    if (projectId != null && sessionId != null) {
      await _prefs.setString('last_session_\$projectId', sessionId);
    }
  }
}

/// Controller for session logic
class SessionController {
  final Ref _ref;

  SessionController(this._ref);

  /// Ensures a valid session is selected for the given project
  Future<void> ensureSessionSelected(String projectId) async {
    final sessionDao = _ref.read(databaseProvider).sessionDao;
    final sessions = await sessionDao.getNonArchivedSessionsByProject(
      projectId,
    );

    if (sessions.isEmpty) {
      // Create new session if none exist
      final projectDao = _ref.read(databaseProvider).projectDao;
      final newSessionId = await sessionDao.createSessionWithId(
        projectId: projectId,
      );

      await _ref.read(currentSessionIdProvider.notifier).select(newSessionId);
      await projectDao.updateLastSessionDate(projectId, DateTime.now());
    } else {
      // Try to restore last selected session
      final prefs = _ref.read(sharedPreferencesProvider);
      final lastSessionId = prefs.getString('last_session_\$projectId');

      if (lastSessionId != null && sessions.any((s) => s.id == lastSessionId)) {
        await _ref
            .read(currentSessionIdProvider.notifier)
            .select(lastSessionId);
      } else {
        // Select the most recent session
        // Note: Assuming getNonArchivedSessionsByProject returns sorted by date desc
        await _ref
            .read(currentSessionIdProvider.notifier)
            .select(sessions.first.id);
      }
    }
  }

  Future<void> createNewSession() async {
    final projectId = _ref.read(currentProjectIdProvider);
    if (projectId == null) return;

    final sessionDao = _ref.read(databaseProvider).sessionDao;
    final projectDao = _ref.read(databaseProvider).projectDao;

    final newSessionId = await sessionDao.createSessionWithId(
      projectId: projectId,
    );
    await _ref.read(currentSessionIdProvider.notifier).select(newSessionId);
    await projectDao.updateLastSessionDate(projectId, DateTime.now());
  }
}
