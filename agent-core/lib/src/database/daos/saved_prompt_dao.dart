import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/saved_prompts_table.dart';

part 'saved_prompt_dao.g.dart';

/// Data Access Object for SavedPrompts table.
/// Provides CRUD operations and reactive queries for saved prompts.
@DriftAccessor(tables: [SavedPrompts])
class SavedPromptDao extends DatabaseAccessor<GlobalDatabase>
    with _$SavedPromptDaoMixin {
  SavedPromptDao(super.db);

  /// Watch all global saved prompts (projectId is null)
  watchGlobalSavedPrompts() {
    return (select(savedPrompts)
          ..where((s) =>
              s.projectId.isNull() &
              const CustomExpression<bool>('is_deleted').equals(false))
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Watch saved prompts for a specific project
  watchProjectSavedPrompts(String projectId) {
    return (select(savedPrompts)
          ..where((s) =>
              s.projectId.equals(projectId) &
              const CustomExpression<bool>('is_deleted').equals(false))
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Get all global saved prompts
  getGlobalSavedPrompts() {
    return (select(savedPrompts)
          ..where((s) =>
              s.projectId.isNull() &
              const CustomExpression<bool>('is_deleted').equals(false))
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// Get saved prompts for a specific project
  getProjectSavedPrompts(String projectId) {
    return (select(savedPrompts)
          ..where((s) =>
              s.projectId.equals(projectId) &
              const CustomExpression<bool>('is_deleted').equals(false))
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// Get a single saved prompt by ID
  getSavedPrompt(String id) {
    return (select(savedPrompts)
          ..where((s) =>
              s.id.equals(id) &
              const CustomExpression<bool>('is_deleted').equals(false)))
        .getSingleOrNull();
  }

  /// Watch a single saved prompt by ID
  watchSavedPrompt(String id) {
    return (select(
      savedPrompts,
    )..where((s) =>
            s.id.equals(id) &
            const CustomExpression<bool>('is_deleted').equals(false)))
        .watchSingleOrNull();
  }

  /// Insert a new saved prompt
  Future<int> insertSavedPrompt(SavedPromptEntityCompanion savedPrompt) {
    return into(savedPrompts).insert(savedPrompt);
  }

  /// Update an existing saved prompt
  Future<int> updateSavedPrompt(SavedPromptEntityCompanion savedPrompt) {
    return (update(
      savedPrompts,
    )..where((s) => s.id.equals(savedPrompt.id.value)))
        .write(savedPrompt);
  }

  /// Delete a saved prompt by ID
  Future<int> deleteSavedPrompt(String id) {
    return (delete(savedPrompts)..where((s) => s.id.equals(id))).go();
  }

  /// Search saved prompts by content
  searchSavedPrompts(
    String query, {
    String? projectId,
  }) {
    final searchQuery = select(savedPrompts)
      ..where((s) =>
          (s.content.like('%$query%')) &
          const CustomExpression<bool>('is_deleted').equals(false));

    if (projectId != null) {
      searchQuery.where((s) => s.projectId.equals(projectId));
    } else {
      searchQuery.where((s) => s.projectId.isNull());
    }

    return (searchQuery
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }
}
