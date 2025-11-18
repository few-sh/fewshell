import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/sessions_table.dart';
import '../../utils/id_generator.dart';

part 'session_dao.g.dart';

/// Data Access Object for Sessions table.
/// Provides CRUD operations and reactive queries.
@DriftAccessor(tables: [Sessions])
class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
  SessionDao(AppDatabase db) : super(db);

  /// Watch sessions for a specific project, ordered by timestamp desc
  Stream<List<SessionEntity>> watchSessionsByProject(String projectId) {
    return (select(sessions)
          ..where((s) => s.projectId.equals(projectId))
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
            (s) => s.projectId.equals(projectId) & s.isArchived.equals(false),
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
            (s) => s.projectId.equals(projectId) & s.isArchived.equals(true),
          )
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Get a single session by ID
  Future<SessionEntity?> getSession(String id) {
    return (select(sessions)..where((s) => s.id.equals(id))).getSingleOrNull();
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
    )..where((s) => s.id.equals(session.id.value))).write(session);
  }

  /// Delete a session by ID
  Future<int> deleteSession(String id) {
    return (delete(sessions)..where((s) => s.id.equals(id))).go();
  }

  /// Delete all sessions for a project
  Future<int> deleteSessionsByProject(String projectId) {
    return (delete(sessions)..where((s) => s.projectId.equals(projectId))).go();
  }

  /// Get sessions for a project
  Future<List<SessionEntity>> getSessionsByProject(String projectId) {
    return (select(sessions)
          ..where((s) => s.projectId.equals(projectId))
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.timestamp, mode: OrderingMode.desc),
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

  /// Delete all archived sessions for a specific project
  Future<int> deleteArchivedSessionsByProject(String projectId) {
    return (delete(sessions)..where(
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
      description: Value(description ?? 'New conversation'),
      timestamp: Value(now),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await insertSession(companion);
    return id;
  }
}
