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
  Future<int> insertMessage(MessageEntityCompanion message) {
    return into(messages).insert(message);
  }

  /// Update an existing message
  Future<bool> updateMessage(MessageEntityCompanion message) {
    return update(messages).replace(message);
  }

  /// Delete a message by ID
  Future<int> deleteMessage(String id) {
    return (delete(messages)..where((m) => m.id.equals(id))).go();
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
