import 'package:drift/drift.dart';
import '../database.dart'; // For SavedPromptEntityCompanion
import '../tables/project_saved_prompts_table.dart';
import '../entities/saved_prompt_entity.dart';

part 'project_saved_prompt_dao.g.dart';

/// Data Access Object for SavedPrompts table in Project Database.
/// Provides CRUD operations and reactive queries for project-specific saved prompts.
@DriftAccessor(tables: [ProjectSavedPrompts])
class ProjectSavedPromptDao extends DatabaseAccessor<ProjectDatabase>
    with _$ProjectSavedPromptDaoMixin {
  ProjectSavedPromptDao(super.db);

  SavedPromptEntity _toEntity(ProjectSavedPrompt s) {
    return SavedPromptEntity(
      id: s.id,
      projectId: s.projectId,
      content: s.content,
      description: s.description,
      tags: s.tags,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
      lastUsedAt: s.lastUsedAt,
    );
  }

  ProjectSavedPromptCompanion _toCompanion(SavedPromptEntityCompanion c) {
    return ProjectSavedPromptCompanion(
      id: c.id,
      projectId: c.projectId,
      content: c.content,
      description: c.description,
      tags: c.tags,
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
      lastUsedAt: c.lastUsedAt,
    );
  }

  /// Watch saved prompts for a specific project
  Stream<List<SavedPromptEntity>> watchProjectSavedPrompts(String projectId) {
    return (select(projectSavedPrompts)
          ..where((s) =>
              s.projectId.equals(projectId) &
              const CustomExpression<bool>('is_deleted').equals(false))
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc),
          ]))
        .watch()
        .map((rows) => rows.map(_toEntity).toList());
  }

  /// Get saved prompts for a specific project
  Future<List<SavedPromptEntity>> getProjectSavedPrompts(
      String projectId) async {
    final rows = await (select(projectSavedPrompts)
          ..where((s) =>
              s.projectId.equals(projectId) &
              const CustomExpression<bool>('is_deleted').equals(false))
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
    return rows.map(_toEntity).toList();
  }

  /// Get a single saved prompt by ID
  Future<SavedPromptEntity?> getSavedPrompt(String id) async {
    final row = await (select(projectSavedPrompts)
          ..where((s) =>
              s.id.equals(id) &
              const CustomExpression<bool>('is_deleted').equals(false)))
        .getSingleOrNull();
    return row != null ? _toEntity(row) : null;
  }

  /// Watch a single saved prompt by ID
  Stream<SavedPromptEntity?> watchSavedPrompt(String id) {
    return (select(
      projectSavedPrompts,
    )..where((s) =>
            s.id.equals(id) &
            const CustomExpression<bool>('is_deleted').equals(false)))
        .watchSingleOrNull()
        .map((row) => row != null ? _toEntity(row) : null);
  }

  /// Insert a new saved prompt
  Future<int> insertSavedPrompt(SavedPromptEntityCompanion savedPrompt) {
    return into(projectSavedPrompts).insert(_toCompanion(savedPrompt));
  }

  /// Update an existing saved prompt
  Future<int> updateSavedPrompt(SavedPromptEntityCompanion savedPrompt) {
    return (update(
      projectSavedPrompts,
    )..where((s) => s.id.equals(savedPrompt.id.value)))
        .write(_toCompanion(savedPrompt));
  }

  /// Delete a saved prompt by ID
  Future<int> deleteSavedPrompt(String id) {
    return (delete(projectSavedPrompts)..where((s) => s.id.equals(id))).go();
  }

  /// Search saved prompts by content
  Future<List<SavedPromptEntity>> searchSavedPrompts(
    String query, {
    String? projectId,
  }) async {
    final searchQuery = select(projectSavedPrompts)
      ..where((s) =>
          (s.content.like('%$query%')) &
          const CustomExpression<bool>('is_deleted').equals(false));

    if (projectId != null) {
      searchQuery.where((s) => s.projectId.equals(projectId));
    }

    final rows = await (searchQuery
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
    return rows.map(_toEntity).toList();
  }
}
