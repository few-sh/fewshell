import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/snippets_table.dart';

part 'snippet_dao.g.dart';

/// Data Access Object for Snippets table.
/// Provides CRUD operations and reactive queries for snippets.
@DriftAccessor(tables: [Snippets])
class SnippetDao extends DatabaseAccessor<AppDatabase> with _$SnippetDaoMixin {
  SnippetDao(AppDatabase db) : super(db);

  /// Watch all global snippets (projectId is null)
  Stream<List<SnippetEntity>> watchGlobalSnippets() {
    return (select(snippets)
          ..where((s) => s.projectId.isNull())
          ..orderBy([
            (s) => OrderingTerm(expression: s.position, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  /// Watch snippets for a specific project
  Stream<List<SnippetEntity>> watchProjectSnippets(String projectId) {
    return (select(snippets)
          ..where((s) => s.projectId.equals(projectId))
          ..orderBy([
            (s) => OrderingTerm(expression: s.position, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  /// Get all global snippets
  Future<List<SnippetEntity>> getGlobalSnippets() {
    return (select(snippets)
          ..where((s) => s.projectId.isNull())
          ..orderBy([
            (s) => OrderingTerm(expression: s.position, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Get snippets for a specific project
  Future<List<SnippetEntity>> getProjectSnippets(String projectId) {
    return (select(snippets)
          ..where((s) => s.projectId.equals(projectId))
          ..orderBy([
            (s) => OrderingTerm(expression: s.position, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Get a single snippet by ID
  Future<SnippetEntity?> getSnippet(String id) {
    return (select(snippets)..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  /// Watch a single snippet by ID
  Stream<SnippetEntity?> watchSnippet(String id) {
    return (select(
      snippets,
    )..where((s) => s.id.equals(id))).watchSingleOrNull();
  }

  /// Insert a new snippet
  Future<int> insertSnippet(SnippetEntityCompanion snippet) {
    return into(snippets).insert(snippet);
  }

  /// Update an existing snippet
  Future<int> updateSnippet(SnippetEntityCompanion snippet) {
    return (update(
      snippets,
    )..where((s) => s.id.equals(snippet.id.value))).write(snippet);
  }

  /// Delete a snippet by ID
  Future<int> deleteSnippet(String id) {
    return (delete(snippets)..where((s) => s.id.equals(id))).go();
  }

  /// Search snippets by name or content
  Future<List<SnippetEntity>> searchSnippets(
    String query, {
    String? projectId,
  }) {
    final searchQuery = select(snippets)
      ..where((s) => s.name.like('%$query%') | s.content.like('%$query%'));

    if (projectId != null) {
      searchQuery.where((s) => s.projectId.equals(projectId));
    } else {
      searchQuery.where((s) => s.projectId.isNull());
    }

    return (searchQuery..orderBy([(s) => OrderingTerm(expression: s.name)]))
        .get();
  }

  /// Get the maximum position value for snippets in a given scope
  Future<int> getMaxPosition({String? projectId}) async {
    final query = selectOnly(snippets)..addColumns([snippets.position.max()]);

    if (projectId != null) {
      query.where(snippets.projectId.equals(projectId));
    } else {
      query.where(snippets.projectId.isNull());
    }

    final result = await query.getSingleOrNull();
    return result?.read(snippets.position.max()) ?? -1;
  }

  /// Update snippet order (deprecated - use position field instead)
  @Deprecated('Use position field for ordering instead')
  Future<void> updateSnippetOrder(String id) {
    return (update(snippets)..where((s) => s.id.equals(id))).write(
      SnippetEntityCompanion(updatedAt: Value(DateTime.now())),
    );
  }
}
