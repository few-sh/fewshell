import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/projects_table.dart';

part 'project_dao.g.dart';

/// Data Access Object for Projects table.
/// Provides CRUD operations and reactive queries.
@DriftAccessor(tables: [Projects])
class ProjectDao extends DatabaseAccessor<AppDatabase> with _$ProjectDaoMixin {
  ProjectDao(AppDatabase db) : super(db);

  /// Watch all projects, ordered by last session date
  Stream<List<ProjectEntity>> watchAllProjects() {
    return (select(projects)..orderBy([
          (p) => OrderingTerm(
            expression: p.lastSessionDate,
            mode: OrderingMode.desc,
          ),
        ]))
        .watch();
  }

  /// Watch a single project by ID
  Stream<ProjectEntity?> watchProject(String id) {
    return (select(
      projects,
    )..where((p) => p.id.equals(id))).watchSingleOrNull();
  }

  /// Get a single project by ID
  Future<ProjectEntity?> getProject(String id) {
    return (select(projects)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  /// Get all projects
  Future<List<ProjectEntity>> getAllProjects() {
    return (select(projects)..orderBy([
          (p) => OrderingTerm(
            expression: p.lastSessionDate,
            mode: OrderingMode.desc,
          ),
        ]))
        .get();
  }

  /// Insert a new project
  Future<int> insertProject(ProjectEntityCompanion project) {
    return into(projects).insert(project);
  }

  /// Update an existing project
  Future<bool> updateProject(ProjectEntityCompanion project) {
    return update(projects).replace(project);
  }

  /// Delete a project by ID
  Future<int> deleteProject(String id) {
    return (delete(projects)..where((p) => p.id.equals(id))).go();
  }

  /// Update last session date for a project
  Future<int> updateLastSessionDate(String id, DateTime date) {
    return (update(projects)..where((p) => p.id.equals(id))).write(
      ProjectEntityCompanion(
        lastSessionDate: Value(date),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Search projects by name
  Future<List<ProjectEntity>> searchProjectsByName(String query) {
    return (select(projects)
          ..where((p) => p.name.like('%$query%'))
          ..orderBy([(p) => OrderingTerm(expression: p.name)]))
        .get();
  }
}
