import 'package:drift/drift.dart';
import 'package:agent_core/agent_core.dart';

part 'message_dao.g.dart';

/// Data Access Object for Messages table.
/// Provides CRUD operations and reactive queries.
@DriftAccessor(tables: [Messages])
class MessageDao extends DatabaseAccessor<ProjectDatabase>
    with _$MessageDaoMixin {
  MessageDao(super.db);

  /// Watch messages for a specific session, ordered by creation time asc
  Stream<List<MessageEntity>> watchMessagesBySession(String sessionId) {
    return (select(messages)
          ..where(
            (m) =>
                m.sessionId.equals(sessionId) &
                const CustomExpression<bool>('is_deleted').equals(false),
          )
          ..orderBy([
            (m) =>
                OrderingTerm(expression: m.createdAt, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  /// Watch completed messages (not streaming) for a specific session
  Stream<List<MessageEntity>> watchCompletedMessagesBySession(
    String sessionId,
  ) {
    return _watchMessagesBySession(sessionId, isStreaming: false);
  }

  /// Watch streaming messages for a specific session
  Stream<List<MessageEntity>> watchStreamingMessagesBySession(
    String sessionId,
  ) {
    return _watchMessagesBySession(sessionId, isStreaming: true);
  }

  /// Helper to watch messages with a filter on streaming status
  Stream<List<MessageEntity>> _watchMessagesBySession(
    String sessionId, {
    required bool isStreaming,
  }) {
    return (select(messages)
          ..where(
            (m) =>
                m.sessionId.equals(sessionId) &
                m.isStreaming.equals(isStreaming) &
                const CustomExpression<bool>('is_deleted').equals(false),
          )
          ..orderBy([
            (m) =>
                OrderingTerm(expression: m.createdAt, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  /// Get a single message by ID
  Future<MessageEntity?> getMessage(String id) {
    return (select(messages)
          ..where(
            (m) =>
                m.id.equals(id) &
                const CustomExpression<bool>('is_deleted').equals(false),
          ))
        .getSingleOrNull();
  }

  /// Insert a new message
  Future<int> insertMessage(MessageEntityCompanion message) async {
    final result =
        await into(messages).insert(message, mode: InsertMode.insertOrReplace);
    return result;
  }

  /// Update an existing message
  Future<bool> updateMessage(MessageEntityCompanion message) async {
    final result = await update(messages).replace(message);
    return result;
  }

  /// Delete a message by ID
  Future<int> deleteMessage(String id) async {
    // Explicitly perform soft delete by setting is_deleted = 1.
    // We use customUpdate because the isDeleted column is managed by sqlite_crdt
    // and not exposed in the Drift table definition.
    final result = await customUpdate(
      'UPDATE messages SET is_deleted = 1 WHERE id = ?',
      variables: [Variable.withString(id)],
      updates: {messages},
    );
    return result;
  }

  /// Delete all messages for a session
  Future<int> deleteMessagesBySession(String sessionId) {
    // Explicitly perform soft delete by setting is_deleted = 1.
    return customUpdate(
      'UPDATE messages SET is_deleted = 1 WHERE session_id = ?',
      variables: [Variable.withString(sessionId)],
      updates: {messages},
    );
  }

  // Update message streaming status
  Future<int> updateMessageStreamingStatus(
    String messageId,
    bool isStreaming,
  ) async {
    final companion = MessageEntityCompanion(
      isStreaming: Value(isStreaming),
    );
    final numWritten = await (update(messages)
          ..where(
            (m) => m.id.equals(messageId),
          ))
        .write(companion);
    return numWritten;
  }

  /// Get messages for a session
  Future<List<MessageEntity>> getMessagesBySession(String sessionId) {
    return (select(messages)
          ..where(
            (m) =>
                m.sessionId.equals(sessionId) &
                const CustomExpression<bool>('is_deleted').equals(false),
          )
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
      ..where(
        messages.sessionId.equals(sessionId) &
            const CustomExpression<bool>('is_deleted').equals(false),
      );
    return query.map((row) => row.read(count)!).getSingle();
  }

  /// Get the last message in a session
  Future<MessageEntity?> getLastMessage(String sessionId) {
    return (select(messages)
          ..where(
            (m) =>
                m.sessionId.equals(sessionId) &
                const CustomExpression<bool>('is_deleted').equals(false),
          )
          ..orderBy([
            (m) =>
                OrderingTerm(expression: m.createdAt, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Generate a unique message ID
  String generateMessageId() => IdGenerator.messageId();

  /// Insert a message with all parameters, generating ID if not provided
  /// This is a convenience method for simple text messages
  Future<String> insertMessageWithId({
    String? id,
    required String sessionId,
    required String userId,
    required String userName,
    required String content,
    String? imageUrl,
    bool isStreaming = false,
    bool isVisibleToLlm = true,
  }) async {
    final now = DateTime.now();
    final messageId = id ?? generateMessageId();

    final companion = MessageEntityCompanion(
      id: Value(messageId),
      sessionId: Value(sessionId),
      userId: Value(userId),
      userName: Value(userName),
      content: Value(content),
      timestamp: Value(now),
      createdAt: Value(now),
      messageKind: Value(
        imageUrl != null ? MessageKind.imageUrl : MessageKind.text,
      ),
      imageUrl: Value(imageUrl),
      toolCallsJson: const Value(null),
      toolResultsJson: const Value(null),
      isStreaming: Value(isStreaming),
      isVisibleToLlm: Value(isVisibleToLlm),
    );

    await insertMessage(companion);
    return messageId;
  }

  /// Update message content and set editedAt timestamp
  Future<MessageEntity?> updateMessageContent({
    required String messageId,
    required String newContent,
  }) async {
    // Get the current message
    final message = await getMessage(messageId);
    if (message == null) return null;

    final now = DateTime.now();

    // Build the update companion
    final companion = MessageEntityCompanion(
      id: Value(messageId),
      sessionId: Value(message.sessionId),
      userId: Value(message.userId),
      userName: Value(message.userName),
      content: Value(newContent),
      timestamp: Value(message.timestamp),
      createdAt: Value(message.createdAt),
      editedAt: Value(now),
      messageKind: Value(message.messageKind),
      imageUrl: Value(message.imageUrl),
      toolCallsJson: Value(message.toolCallsJson),
      toolResultsJson: Value(message.toolResultsJson),
      isVisibleToLlm: Value(message.isVisibleToLlm),
    );

    final success = await updateMessage(companion);
    if (!success) return null;

    return message.copyWith(
      content: newContent,
      editedAt: Value(now),
    );
  }

  /// Delete all messages after a specific message (by timestamp)
  /// Used when editing a message to remove subsequent conversation
  Future<int> deleteMessagesAfter({
    required String sessionId,
    required DateTime afterTimestamp,
  }) async {
    // Explicitly perform soft delete by setting is_deleted = 1.
    // We use customUpdate because the isDeleted column is managed by sqlite_crdt
    // and not exposed in the Drift table definition.
    final result = await customUpdate(
      'UPDATE messages SET is_deleted = 1 WHERE session_id = ? AND timestamp > ?',
      variables: [
        Variable.withString(sessionId),
        Variable.withDateTime(afterTimestamp),
      ],
      updates: {messages},
    );
    return result;
  }
}
