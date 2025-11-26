import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';
import 'project_provider.dart';
import 'session_provider.dart';
import 'session_controller_provider.dart';

/// Provider for local (Drift) messages by session.
/// This is a family provider keyed by sessionId.
final _localMessagesProvider = StreamProvider.family<List<dynamic>, String>((
  ref,
  sessionId,
) {
  final messageDao = ref.watch(databaseProvider).messageDao;
  return messageDao.watchMessagesBySession(sessionId);
});

/// Provider for messages of the currently selected session.
///
/// This is a hybrid provider that uses:
/// - SessionController (agent-core) for remote projects
/// - Direct Drift DAO for local projects (fallback while migrating)
///
/// The return type is `dynamic` to support both Message and MessageEntity
/// during the migration period.
final currentSessionMessagesProvider = Provider<AsyncValue<List<dynamic>>>((
  ref,
) {
  final project = ref.watch(currentProjectProvider);
  final sessionId = ref.watch(currentSessionIdProvider);

  if (sessionId == null) {
    return const AsyncValue.data([]);
  }

  // For remote projects, use SessionController
  if (project?.serverUrl != null && project!.serverUrl!.isNotEmpty) {
    final messagesAsync = ref.watch(controllerMessagesProvider(sessionId));
    return messagesAsync.whenData((messages) => messages.cast<dynamic>());
  }

  // For local projects, use Drift DAO via family provider
  return ref.watch(_localMessagesProvider(sessionId));
});
