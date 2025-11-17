import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/messages_table.dart';

part 'message_dao.g.dart';

/// Data Access Object for Messages table.
/// Provides CRUD operations and reactive queries.
@DriftAccessor(tables: [Messages])
class MessageDao extends DatabaseAccessor<AppDatabase> with _$MessageDaoMixin {
  MessageDao(AppDatabase db) : super(db);

  /// Watch messages for a specific session, ordered by creation time asc
  Stream<List<MessageEntity>> watchMessagesBySession(String sessionId) {
    return (select(messages)
          ..where((m) => m.sessionId.equals(sessionId))
          ..orderBy([
            (m) =>
                OrderingTerm(expression: m.createdAt, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  /// Get a single message by ID
  Future<MessageEntity?> getMessage(String id) {
    return (select(messages)..where((m) => m.id.equals(id))).getSingleOrNull();
  }

  /// Insert a new message
  Future<int> insertMessage(MessageEntityCompanion message) async {
    final result = await into(messages).insert(message);
    // Touch the session to update its updatedAt timestamp
    if (message.sessionId.present) {
      await db.sessionDao.touchSession(message.sessionId.value);
    }
    return result;
  }

  /// Update an existing message
  Future<bool> updateMessage(MessageEntityCompanion message) async {
    final result = await update(messages).replace(message);
    // Touch the session to update its updatedAt timestamp
    if (message.sessionId.present) {
      await db.sessionDao.touchSession(message.sessionId.value);
    }
    return result;
  }

  /// Delete a message by ID
  Future<int> deleteMessage(String id) async {
    // Get the message first to know which session to touch
    final message = await getMessage(id);
    final result = await (delete(messages)..where((m) => m.id.equals(id))).go();
    // Touch the session to update its updatedAt timestamp
    if (message != null) {
      await db.sessionDao.touchSession(message.sessionId);
    }
    return result;
  }

  /// Delete all messages for a session
  Future<int> deleteMessagesBySession(String sessionId) {
    return (delete(messages)..where((m) => m.sessionId.equals(sessionId))).go();
  }

  /// Get messages for a session
  Future<List<MessageEntity>> getMessagesBySession(String sessionId) {
    return (select(messages)
          ..where((m) => m.sessionId.equals(sessionId))
          ..orderBy([
            (m) =>
                OrderingTerm(expression: m.createdAt, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Get message count for a session
  Future<int> getMessageCountBySession(String sessionId) {
    final count = countAll();
    final query = selectOnly(messages)
      ..addColumns([count])
      ..where(messages.sessionId.equals(sessionId));
    return query.map((row) => row.read(count)!).getSingle();
  }
}
