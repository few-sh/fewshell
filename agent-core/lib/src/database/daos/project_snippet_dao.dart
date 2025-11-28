import 'package:drift/drift.dart';
import '../database.dart'; // For SnippetEntityCompanion
import '../tables/project_snippets_table.dart';
import '../entities/snippet_entity.dart';

part 'project_snippet_dao.g.dart';

/// Data Access Object for Snippets table in Project Database.
/// Provides CRUD operations and reactive queries for project-specific snippets.
@DriftAccessor(tables: [ProjectSnippets])
class ProjectSnippetDao extends DatabaseAccessor<ProjectDatabase>
    with _$ProjectSnippetDaoMixin {
  ProjectSnippetDao(ProjectDatabase db) : super(db);

  SnippetEntity _toEntity(ProjectSnippet s) {
    return SnippetEntity(
      id: s.id,
      projectId: s.projectId,
      name: s.name,
      content: s.content,
      description: s.description,
      tags: s.tags,
      position: s.position,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
    );
  }

  ProjectSnippetCompanion _toCompanion(SnippetEntityCompanion c) {
    return ProjectSnippetCompanion(
      id: c.id,
      projectId: c.projectId,
      name: c.name,
      content: c.content,
      description: c.description,
      tags: c.tags,
      position: c.position,
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
    );
  }

  /// Watch snippets for a specific project
  Stream<List<SnippetEntity>> watchProjectSnippets(String projectId) {
    return (select(projectSnippets)
          ..where((s) => s.projectId.equals(projectId))
          ..orderBy([
            (s) => OrderingTerm(expression: s.position, mode: OrderingMode.asc),
          ]))
        .watch()
        .map((rows) => rows.map(_toEntity).toList());
  }

  /// Get snippets for a specific project
  Future<List<SnippetEntity>> getProjectSnippets(String projectId) {
    return (select(projectSnippets)
          ..where((s) => s.projectId.equals(projectId))
          ..orderBy([
            (s) => OrderingTerm(expression: s.position, mode: OrderingMode.asc),
          ]))
        .get()
        .then((rows) => rows.map(_toEntity).toList());
  }

  /// Get a single snippet by ID
  Future<SnippetEntity?> getSnippet(String id) {
    return (select(projectSnippets)..where((s) => s.id.equals(id)))
        .getSingleOrNull()
        .then((row) => row != null ? _toEntity(row) : null);
  }

  /// Watch a single snippet by ID
  Stream<SnippetEntity?> watchSnippet(String id) {
    return (select(projectSnippets)..where((s) => s.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => row != null ? _toEntity(row) : null);
  }

  /// Insert a new snippet
  Future<int> insertSnippet(SnippetEntityCompanion snippet) {
    return into(projectSnippets).insert(_toCompanion(snippet));
  }

  /// Update an existing snippet
  Future<bool> updateSnippet(SnippetEntityCompanion snippet) {
    return update(projectSnippets).replace(_toCompanion(snippet));
  }

  /// Delete a snippet by ID
  Future<int> deleteSnippet(String id) {
    return (delete(projectSnippets)..where((s) => s.id.equals(id))).go();
  }

  /// Search snippets by name or content
  Future<List<SnippetEntity>> searchSnippets(String query, String projectId) {
    return (select(projectSnippets)
          ..where((s) =>
              (s.name.like('%$query%') | s.content.like('%$query%')) &
              s.projectId.equals(projectId))
          ..orderBy([(s) => OrderingTerm(expression: s.name)]))
        .get()
        .then((rows) => rows.map(_toEntity).toList());
  }

  /// Get the maximum position value for snippets in a given scope
  Future<int> getMaxPosition(String projectId) async {
    final query = selectOnly(projectSnippets)
      ..addColumns([projectSnippets.position.max()])
      ..where(projectSnippets.projectId.equals(projectId));

    final result = await query.getSingleOrNull();
    return result?.read(projectSnippets.position.max()) ?? -1;
  }
}
