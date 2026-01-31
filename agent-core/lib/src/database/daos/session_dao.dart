import 'package:drift/drift.dart';
import 'package:agent_core/agent_core.dart';

part 'session_dao.g.dart';

/// Data Access Object for Sessions table.
/// Provides CRUD operations and reactive queries.
@DriftAccessor(tables: [Sessions])
class SessionDao extends DatabaseAccessor<ProjectDatabase>
    with _$SessionDaoMixin
    implements ListableEntityDao<SessionEntity> {
  SessionDao(super.db);

  /// Watch sessions for a specific project, ordered by timestamp desc
  Stream<List<SessionEntity>> watchSessionsByProject(String projectId) {
    return (select(sessions)
          ..where((s) =>
              s.projectId.equals(projectId) &
              const CustomExpression<bool>('is_deleted').equals(false))
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.timestamp, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Watch non-archived sessions for a specific project, ordered by timestamp desc
  Stream<List<SessionEntity>> watchNonArchivedSessionsByProject(
    String projectId,
  ) {
    return (select(sessions)
          ..where(
            (s) =>
                s.projectId.equals(projectId) &
                s.isArchived.equals(false) &
                const CustomExpression<bool>('is_deleted').equals(false),
          )
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Watch archived sessions for a specific project, ordered by timestamp desc
  Stream<List<SessionEntity>> watchArchivedSessionsByProject(String projectId) {
    return (select(sessions)
          ..where(
            (s) =>
                s.projectId.equals(projectId) &
                s.isArchived.equals(true) &
                const CustomExpression<bool>('is_deleted').equals(false),
          )
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Get a single session by ID
  Future<SessionEntity?> getSession(String id) {
    return (select(sessions)
          ..where((s) =>
              s.id.equals(id) &
              const CustomExpression<bool>('is_deleted').equals(false)))
        .getSingleOrNull();
  }

  /// Insert a new session
  Future<int> insertSession(SessionEntityCompanion session) {
    return into(sessions).insert(session);
  }

  /// Update an existing session
  /// Uses partial updates - only updates fields that are provided
  Future<int> updateSession(SessionEntityCompanion session) {
    return (update(
      sessions,
    )..where((s) => s.id.equals(session.id.value)))
        .write(session);
  }

  /// Delete a session by ID
  Future<int> deleteSession(String id) async {
    // Clean up associated messages
    await db.messageDao.deleteMessagesBySession(id);
    // Clean up associated message subscriptions
    await db.messageSubscriberDao.deleteSubscriptionsBySession(id);

    return (delete(sessions)..where((s) => s.id.equals(id))).go();
  }

  /// Delete all sessions for a project
  Future<int> deleteSessionsByProject(String projectId) {
    return (delete(sessions)..where((s) => s.projectId.equals(projectId))).go();
  }

  /// Get sessions for a project
  Future<List<SessionEntity>> getSessionsByProject(String projectId) {
    return (select(sessions)
          ..where((s) =>
              s.projectId.equals(projectId) &
              const CustomExpression<bool>('is_deleted').equals(false))
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.timestamp, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// Get non-archived sessions for a project
  Future<List<SessionEntity>> getNonArchivedSessionsByProject(
    String projectId,
  ) {
    return (select(sessions)
          ..where(
            (s) =>
                s.projectId.equals(projectId) &
                s.isArchived.equals(false) &
                const CustomExpression<bool>('is_deleted').equals(false),
          )
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.updatedAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// Get session count for a project
  Future<int> getSessionCountByProject(String projectId) {
    final count = countAll();
    final query = selectOnly(sessions)
      ..addColumns([count])
      ..where(sessions.projectId.equals(projectId));
    return query.map((row) => row.read(count)!).getSingle();
  }

  /// Archive a session by setting isArchived to true
  Future<int> archiveSession(String id) {
    return (update(sessions)..where((s) => s.id.equals(id))).write(
      SessionEntityCompanion(isArchived: const Value(true)),
    );
  }

  /// Unarchive a session by setting isArchived to false
  Future<int> unarchiveSession(String id) {
    return (update(sessions)..where((s) => s.id.equals(id))).write(
      SessionEntityCompanion(isArchived: const Value(false)),
    );
  }

  /// Rename a session
  Future<int> renameSession(String id, String newName) {
    return (update(sessions)..where((s) => s.id.equals(id))).write(
      SessionEntityCompanion(description: Value(newName)),
    );
  }

  /// Delete all archived sessions for a specific project
  Future<int> deleteArchivedSessionsByProject(String projectId) {
    return (delete(sessions)
          ..where(
            (s) => s.projectId.equals(projectId) & s.isArchived.equals(true),
          ))
        .go();
  }

  /// Get count of archived sessions for a project
  Future<int> getArchivedSessionCountByProject(String projectId) {
    final count = countAll();
    final query = selectOnly(sessions)
      ..addColumns([count])
      ..where(
        sessions.projectId.equals(projectId) & sessions.isArchived.equals(true),
      );
    return query.map((row) => row.read(count)!).getSingle();
  }

  /// Update the updatedAt timestamp of a session to now
  Future<int> touchSession(String id) {
    return (update(sessions)..where((s) => s.id.equals(id))).write(
      SessionEntityCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  /// Generate a unique session ID
  String generateSessionId() => IdGenerator.sessionId();

  /// Create a new session with all parameters
  Future<String> createSessionWithId({
    required String projectId,
    String? description,
  }) async {
    final now = DateTime.now();
    final id = generateSessionId();

    final companion = SessionEntityCompanion(
      id: Value(id),
      projectId: Value(projectId),
      description: Value(description ?? kDefaultSessionDescription),
      timestamp: Value(now),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await insertSession(companion);
    return id;
  }

  /// Branch a session by creating a deep copy up to a specific message
  /// Creates a new session with "Copy of: " prepended to the name
  /// Copies all messages up to and including the specified message ID
  /// All new entities get fresh IDs
  Future<String> branchSession({
    required String sessionId,
    required String upToMessageId,
  }) async {
    // Get the original session
    final originalSession = await getSession(sessionId);
    if (originalSession == null) {
      throw Exception('Session $sessionId not found');
    }

    // Get all messages up to and including the specified message
    final allMessages = await db.messageDao.getMessagesBySession(sessionId);
    final upToMessage = allMessages.firstWhere(
      (msg) => msg.id == upToMessageId,
      orElse: () => throw Exception('Message $upToMessageId not found'),
    );

    // Filter messages up to and including the target message
    final messagesToCopy = allMessages
        .where(
          (msg) =>
              msg.createdAt.isBefore(upToMessage.createdAt) ||
              msg.createdAt.isAtSameMomentAs(upToMessage.createdAt),
        )
        .toList();

    // Create new session with copied name
    final now = DateTime.now();
    final newSessionId = generateSessionId();
    final newDescription = 'Copy of: ${originalSession.description}';

    final sessionCompanion = SessionEntityCompanion(
      id: Value(newSessionId),
      projectId: Value(originalSession.projectId),
      description: Value(newDescription),
      timestamp: Value(now),
      createdAt: Value(originalSession.createdAt),
      updatedAt: Value(originalSession.updatedAt),
      isArchived: Value(originalSession.isArchived),
    );

    await insertSession(sessionCompanion);

    // Deep copy all messages with new IDs
    for (final msg in messagesToCopy) {
      final newMessageId = db.messageDao.generateMessageId();
      final messageCompanion = MessageEntityCompanion(
        id: Value(newMessageId),
        sessionId: Value(newSessionId),
        userId: Value(msg.userId),
        userName: Value(msg.userName),
        content: Value(msg.content),
        timestamp: Value(msg.timestamp),
        createdAt: Value(msg.createdAt),
        editedAt: Value(msg.editedAt),
        messageKind: Value(msg.messageKind),
        imageUrl: Value(msg.imageUrl),
        toolCallsJson: Value(msg.toolCallsJson),
        toolResultsJson: Value(msg.toolResultsJson),
      );

      await db.messageDao.insertMessage(messageCompanion);
    }

    return newSessionId;
  }

  // --- ListableEntityDao interface implementation ---

  @override
  Future<void> archiveItem(String id) => archiveSession(id);

  @override
  Future<void> unarchiveItem(String id) => unarchiveSession(id);

  @override
  Future<void> deleteItem(String id) => deleteSession(id);

  @override
  Future<void> renameItem(String id, String newName) =>
      renameSession(id, newName);
}
