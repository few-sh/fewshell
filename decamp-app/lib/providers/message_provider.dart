import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';
import 'project_provider.dart';
import 'session_provider.dart';
import 'session_controller_provider.dart';

/// Provider for messages of the currently selected session.
///
/// This is a hybrid provider that uses:
/// - SessionController (agent-core) for remote projects
/// - Direct Drift DAO for local projects (fallback while migrating)
///
/// The return type is `dynamic` to support both Message and MessageEntity
/// during the migration period.
final currentSessionMessagesProvider = StreamProvider<List<dynamic>>((ref) {
  final project = ref.watch(currentProjectProvider);
  final sessionId = ref.watch(currentSessionIdProvider);

  if (sessionId == null) {
    return Stream.value([]);
  }

  // For remote projects, use SessionController
  if (project?.serverUrl != null && project!.serverUrl!.isNotEmpty) {
    return ref.watch(controllerMessagesProvider(sessionId).stream);
  }

  // For local projects, use Drift DAO (for now - will migrate to SessionController)
  final messageDao = ref.watch(databaseProvider).messageDao;
  return messageDao.watchMessagesBySession(sessionId);
});
