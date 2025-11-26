import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session_provider.dart';
import 'session_controller_provider.dart';

/// Provider for messages of the currently selected session.
///
/// Uses SessionController (agent-core) exclusively:
/// - Local project: LocalSessionController
/// - Remote project: RemoteSessionController
///
/// Both return agent-core Message models directly.
final currentSessionMessagesProvider = Provider<AsyncValue<List<dynamic>>>((
  ref,
) {
  final sessionId = ref.watch(currentSessionIdProvider);

  if (sessionId == null) {
    return const AsyncValue.data([]);
  }

  // Use SessionController for both local and remote projects
  final messagesAsync = ref.watch(controllerMessagesProvider(sessionId));
  return messagesAsync.whenData((messages) => messages.cast<dynamic>());
});
