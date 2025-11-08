import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/sessions_table.dart';

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
}
