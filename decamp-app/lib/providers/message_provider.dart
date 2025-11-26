import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'database_provider.dart';
import 'session_provider.dart';

/// Provider for messages of the currently selected session
final currentSessionMessagesProvider = StreamProvider<List<MessageEntity>>((
  ref,
) {
  final sessionId = ref.watch(currentSessionIdProvider);
  if (sessionId == null) {
    return Stream.value([]);
  }
  final messageDao = ref.watch(databaseProvider).messageDao;
  return messageDao.watchMessagesBySession(sessionId);
});
