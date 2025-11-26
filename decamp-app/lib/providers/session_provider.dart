import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'project_provider.dart';
import 'session_controller_provider.dart';

/// Provider for sessions of the currently selected project.
///
/// Uses SessionController (agent-core) exclusively:
/// - Local project: LocalSessionController
/// - Remote project: RemoteSessionController
///
/// Both return agent-core Session models directly.
final currentProjectSessionsProvider = Provider<AsyncValue<List<dynamic>>>((
  ref,
) {
  final projectId = ref.watch(currentProjectIdProvider);

  if (projectId == null) {
    return const AsyncValue.data([]);
  }

  // Use SessionController for both local and remote projects
  final sessionsAsync = ref.watch(controllerSessionsProvider);
  return sessionsAsync.whenData((sessions) => sessions.cast<dynamic>());
});

/// Provider for archived sessions of the currently selected project
final archivedSessionsProvider = Provider<AsyncValue<List<dynamic>>>((ref) {
  final projectId = ref.watch(currentProjectIdProvider);

  if (projectId == null) {
    return const AsyncValue.data([]);
  }

  // Use SessionController for both local and remote projects
  final sessionsAsync = ref.watch(controllerArchivedSessionsProvider);
  return sessionsAsync.whenData((sessions) => sessions.cast<dynamic>());
});

/// StateProvider for the currently selected session ID
final currentSessionIdProvider = StateProvider<String?>((ref) => null);

/// Session auto-selector that runs after build
/// Watches project and sessions to ensure a valid session is always selected
final sessionAutoSelectorProvider = Provider<void>((ref) {
  final projectId = ref.watch(currentProjectIdProvider);
  final sessionsAsync = ref.watch(currentProjectSessionsProvider);

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
      // Create new session via SessionController (works for both local and remote)
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
