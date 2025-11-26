import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';
import 'project_provider.dart';
import 'session_controller_provider.dart';

/// Provider for local (Drift) non-archived sessions.
/// This is a family provider keyed by projectId.
final _localSessionsProvider = StreamProvider.family<List<dynamic>, String>((
  ref,
  projectId,
) {
  final sessionDao = ref.watch(databaseProvider).sessionDao;
  return sessionDao.watchNonArchivedSessionsByProject(projectId);
});

/// Provider for local (Drift) archived sessions.
/// This is a family provider keyed by projectId.
final _localArchivedSessionsProvider =
    StreamProvider.family<List<dynamic>, String>((ref, projectId) {
      final sessionDao = ref.watch(databaseProvider).sessionDao;
      return sessionDao.watchArchivedSessionsByProject(projectId);
    });

/// Provider for sessions of the currently selected project.
///
/// This is a hybrid provider that uses:
/// - SessionController (agent-core) for remote projects
/// - Direct Drift DAO for local projects (fallback while migrating)
///
/// The return type is `dynamic` to support both Session and SessionEntity
/// during the migration period. UI uses duck-typing on id, description, etc.
final currentProjectSessionsProvider = Provider<AsyncValue<List<dynamic>>>((
  ref,
) {
  final project = ref.watch(currentProjectProvider);
  final projectId = ref.watch(currentProjectIdProvider);

  if (projectId == null) {
    return const AsyncValue.data([]);
  }

  // For remote projects, use SessionController
  if (project?.serverUrl != null && project!.serverUrl!.isNotEmpty) {
    // Watch the controller sessions and convert to dynamic list
    final sessionsAsync = ref.watch(controllerSessionsProvider);
    return sessionsAsync.whenData((sessions) => sessions.cast<dynamic>());
  }

  // For local projects, use Drift DAO via family provider
  return ref.watch(_localSessionsProvider(projectId));
});

/// Provider for archived sessions of the currently selected project
final archivedSessionsProvider = Provider<AsyncValue<List<dynamic>>>((ref) {
  final project = ref.watch(currentProjectProvider);
  final projectId = ref.watch(currentProjectIdProvider);

  if (projectId == null) {
    return const AsyncValue.data([]);
  }

  // For remote projects, use SessionController
  if (project?.serverUrl != null && project!.serverUrl!.isNotEmpty) {
    final sessionsAsync = ref.watch(controllerArchivedSessionsProvider);
    return sessionsAsync.whenData((sessions) => sessions.cast<dynamic>());
  }

  // For local projects, use Drift DAO via family provider
  return ref.watch(_localArchivedSessionsProvider(projectId));
});

/// StateProvider for the currently selected session ID
final currentSessionIdProvider = StateProvider<String?>((ref) => null);

/// Session auto-selector that runs after build
/// Watches project and sessions to ensure a valid session is always selected
final sessionAutoSelectorProvider = Provider<void>((ref) {
  final project = ref.watch(currentProjectProvider);
  final projectId = ref.watch(currentProjectIdProvider);
  final sessionsAsync = ref.watch(currentProjectSessionsProvider);
  final isRemote = project?.serverUrl != null && project!.serverUrl!.isNotEmpty;

  // Schedule session selection for after the current build
  ref.listenSelf((_, __) {
    if (projectId == null) {
      ref.read(currentSessionIdProvider.notifier).state = null;
      return;
    }

    final sessions = sessionsAsync.when(
      data: (sessions) => sessions,
      loading: () => null,
      error: (_, __) => null,
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
      if (isRemote) {
        // For remote projects, use SessionController
        final controllerAsync = ref.read(sessionControllerProvider);
        controllerAsync.whenData((controller) async {
          if (controller != null) {
            try {
              final newSession = await controller.createSession();
              ref.read(currentSessionIdProvider.notifier).state = newSession.id;
            } catch (e) {
              // Log error but don't crash - session creation failed
              // The user can manually create a session
              developer.log(
                '❌ Failed to auto-create session: $e',
                name: 'SessionAutoSelector',
              );
            }
          }
        });
      } else {
        // For local projects, use Drift DAO
        final sessionDao = ref.read(databaseProvider).sessionDao;
        final projectDao = ref.read(databaseProvider).projectDao;

        sessionDao.createSessionWithId(projectId: projectId).then((
          newSessionId,
        ) {
          ref.read(currentSessionIdProvider.notifier).state = newSessionId;
          projectDao.updateLastSessionDate(projectId, DateTime.now());
        });
      }
    } else {
      // Select most recent session
      ref.read(currentSessionIdProvider.notifier).state = sessions.first.id;
    }
  });
});

/// Provider for the currently selected session.
/// Returns null if no session is selected or session doesn't exist.
/// The return type is dynamic to support both Session (agent-core) and
/// SessionEntity (Drift) during the migration period.
final currentSessionProvider = Provider<dynamic>((ref) {
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
