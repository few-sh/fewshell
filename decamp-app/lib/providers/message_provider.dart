import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'database_provider.dart';
import 'session_provider.dart';

/// Provider for streaming messages for a specific session (family provider)
final messagesStreamProvider =
    StreamProvider.family<List<MessageEntity>, String>((ref, sessionId) {
      final messageDao = ref.watch(messageDaoProvider);
      return messageDao.watchMessagesBySession(sessionId);
    });

/// Provider for messages of the currently selected session
final currentSessionMessagesProvider = StreamProvider<List<MessageEntity>>((
  ref,
) {
  final sessionId = ref.watch(currentSessionIdProvider);
  if (sessionId == null) {
    return Stream.value([]);
  }
  final messageDao = ref.watch(messageDaoProvider);
  return messageDao.watchMessagesBySession(sessionId);
});
