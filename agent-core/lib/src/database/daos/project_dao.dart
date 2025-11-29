import 'package:drift/drift.dart';
import 'package:agent_core/agent_core.dart';

part 'project_dao.g.dart';

/// Data Access Object for Projects table.
/// Provides CRUD operations and reactive queries.
@DriftAccessor(tables: [Projects])
class ProjectDao extends DatabaseAccessor<GlobalDatabase>
    with _$ProjectDaoMixin {
  ProjectDao(super.db);

  /// Watch all projects, ordered by last session date
  Stream<List<ProjectEntity>> watchAllProjects() {
    return (select(projects)
          ..orderBy([
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
    )..where((p) => p.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Get a single project by ID
  Future<ProjectEntity?> getProject(String id) {
    return (select(projects)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  /// Get all projects
  Future<List<ProjectEntity>> getAllProjects() {
    return (select(projects)
          ..orderBy([
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
  Future<int> updateProject(ProjectEntityCompanion project) {
    return (update(
      projects,
    )..where((p) => p.id.equals(project.id.value)))
        .write(project);
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

  /// Generate a unique project ID
  String generateProjectId() => IdGenerator.projectId();

  /// Create a new project with all parameters
  Future<String> createProjectWithId({
    required String name,
    String? description,
  }) async {
    final now = DateTime.now();
    final id = generateProjectId();

    final companion = ProjectEntityCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      lastSessionDate: Value(now),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await insertProject(companion);
    return id;
  }
}
