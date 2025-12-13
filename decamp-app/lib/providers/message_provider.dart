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
  return messageDao.watchCompletedMessagesBySession(sessionId);
});

/// Provider to check if the last message is in progress (streaming)
final isLastMessageInProgressProvider = StreamProvider<bool>((ref) {
  final sessionId = ref.watch(currentSessionIdProvider);
  if (sessionId == null) {
    return Stream.value(false);
  }
  final messageDao = ref.watch(databaseProvider).messageDao;
  // Watch streaming messages. If there are any, it means generation is in progress.
  return messageDao.watchStreamingMessagesBySession(sessionId).map((messages) {
    return messages.isNotEmpty;
  });
});
