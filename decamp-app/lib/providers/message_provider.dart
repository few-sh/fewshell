import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../database/database.dart';
import '../database/daos/message_dao.dart';
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

/// Provider for message actions (CRUD operations)
final messageActionsProvider = Provider<MessageActions>((ref) {
  final messageDao = ref.watch(messageDaoProvider);
  return MessageActions(messageDao);
});

/// Class containing all message-related actions
class MessageActions {
  final MessageDao _messageDao;

  MessageActions(this._messageDao);

  /// Create a new message
  Future<String> insertMessage({
    required String sessionId,
    required String userId,
    required String userName,
    required String content,
    String? imageUrl,
    String? metadata,
  }) async {
    final now = DateTime.now();
    final id = _generateMessageId();

    final companion = MessageEntityCompanion(
      id: drift.Value(id),
      sessionId: drift.Value(sessionId),
      userId: drift.Value(userId),
      userName: drift.Value(userName),
      content: drift.Value(content),
      timestamp: drift.Value(now),
      createdAt: drift.Value(now),
      imageUrl: drift.Value(imageUrl),
      metadata: drift.Value(metadata),
    );

    await _messageDao.insertMessage(companion);
    return id;
  }

  /// Update an existing message
  Future<void> updateMessage({
    required String id,
    String? content,
    String? imageUrl,
    String? metadata,
  }) async {
    final companion = MessageEntityCompanion(
      id: drift.Value(id),
      content: content != null
          ? drift.Value(content)
          : const drift.Value.absent(),
      imageUrl: imageUrl != null
          ? drift.Value(imageUrl)
          : const drift.Value.absent(),
      metadata: metadata != null
          ? drift.Value(metadata)
          : const drift.Value.absent(),
    );

    await _messageDao.updateMessage(companion);
  }

  /// Delete a message
  Future<void> deleteMessage(String id) async {
    await _messageDao.deleteMessage(id);
  }

  /// Delete all messages for a session
  Future<void> deleteMessagesBySession(String sessionId) async {
    await _messageDao.deleteMessagesBySession(sessionId);
  }

  /// Get messages for a session (non-reactive)
  Future<List<MessageEntity>> getMessagesBySession(String sessionId) async {
    return await _messageDao.getMessagesBySession(sessionId);
  }

  /// Get a specific message by ID
  Future<MessageEntity?> getMessage(String id) async {
    return await _messageDao.getMessage(id);
  }

  /// Get message count for a session
  Future<int> getMessageCount(String sessionId) async {
    return await _messageDao.getMessageCountBySession(sessionId);
  }

  /// Generate a unique message ID
  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${_randomString(8)}';
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
