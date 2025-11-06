import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../providers/database_provider.dart';
import '../models/snippet.dart';

/// Stream provider for global snippets
final globalSnippetsStreamProvider = StreamProvider<List<Snippet>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.snippetDao.watchGlobalSnippets().map((entities) {
    return entities.map(_entityToModel).toList();
  });
});

/// Stream provider for project snippets (family provider)
final projectSnippetsStreamProvider =
    StreamProvider.family<List<Snippet>, String>((ref, projectId) {
      final db = ref.watch(databaseProvider);
      return db.snippetDao.watchProjectSnippets(projectId).map((entities) {
        return entities.map(_entityToModel).toList();
      });
    });

/// State notifier provider for managing global snippets
final globalSnippetsProvider =
    StateNotifierProvider<SnippetNotifier, AsyncValue<List<Snippet>>>((ref) {
      final db = ref.watch(databaseProvider);
      return SnippetNotifier(db, null);
    });

/// State notifier provider for managing project snippets (family provider)
final projectSnippetsProvider =
    StateNotifierProvider.family<
      SnippetNotifier,
      AsyncValue<List<Snippet>>,
      String
    >((ref, projectId) {
      final db = ref.watch(databaseProvider);
      return SnippetNotifier(db, projectId);
    });

/// State notifier for managing snippets
class SnippetNotifier extends StateNotifier<AsyncValue<List<Snippet>>> {
  final AppDatabase _db;
  final String? _projectId;

  SnippetNotifier(this._db, this._projectId)
    : super(const AsyncValue.loading()) {
    _loadSnippets();
  }

  Future<void> _loadSnippets() async {
    try {
      final entities = _projectId == null
          ? await _db.snippetDao.getGlobalSnippets()
          : await _db.snippetDao.getProjectSnippets(_projectId);

      state = AsyncValue.data(entities.map(_entityToModel).toList());
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Add a new snippet
  Future<void> addSnippet({
    required String name,
    required String content,
    String? description,
    List<String> tags = const [],
  }) async {
    try {
      final now = DateTime.now();
      final snippet = SnippetEntityCompanion(
        id: Value(_generateSnippetId()),
        projectId: Value(_projectId),
        name: Value(name),
        content: Value(content),
        description: Value(description),
        tags: Value(tags.join(',')),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await _db.snippetDao.insertSnippet(snippet);
      await _loadSnippets();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Update an existing snippet
  Future<void> updateSnippet({
    required String id,
    String? name,
    String? content,
    String? description,
    List<String>? tags,
  }) async {
    try {
      final snippet = SnippetEntityCompanion(
        id: Value(id),
        name: name != null ? Value(name) : const Value.absent(),
        content: content != null ? Value(content) : const Value.absent(),
        description: description != null
            ? Value(description)
            : const Value.absent(),
        tags: tags != null ? Value(tags.join(',')) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      );

      await _db.snippetDao.updateSnippet(snippet);
      await _loadSnippets();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Delete a snippet
  Future<void> deleteSnippet(String id) async {
    try {
      await _db.snippetDao.deleteSnippet(id);
      await _loadSnippets();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Reorder snippets (updates the updatedAt timestamp to change order)
  Future<void> reorderSnippets(int oldIndex, int newIndex) async {
    try {
      final currentState = state;
      if (!currentState.hasValue) return;

      final snippets = List<Snippet>.from(currentState.value!);

      // Adjust newIndex if moving down
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final snippet = snippets.removeAt(oldIndex);
      snippets.insert(newIndex, snippet);

      // Update state optimistically
      state = AsyncValue.data(snippets);

      // Update timestamps in reverse order to maintain the new order
      for (int i = snippets.length - 1; i >= 0; i--) {
        await _db.snippetDao.updateSnippet(
          SnippetEntityCompanion(
            id: Value(snippets[i].id),
            updatedAt: Value(
              DateTime.now().subtract(Duration(seconds: snippets.length - i)),
            ),
          ),
        );
      }

      await _loadSnippets();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      await _loadSnippets(); // Reload to revert optimistic update
      rethrow;
    }
  }

  /// Generate a unique snippet ID
  String _generateSnippetId() {
    return 'snip_${DateTime.now().millisecondsSinceEpoch}_${_randomString(8)}';
  }

  /// Generate a random string for ID uniqueness
  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      length,
      (index) => chars[(DateTime.now().microsecond + index) % chars.length],
    ).join();
  }
}

/// Helper function to convert entity to model
Snippet _entityToModel(SnippetEntity entity) {
  return Snippet(
    id: entity.id,
    projectId: entity.projectId,
    name: entity.name,
    content: entity.content,
    description: entity.description,
    tags: entity.tags.isEmpty ? [] : entity.tags.split(','),
    createdAt: entity.createdAt,
    updatedAt: entity.updatedAt,
  );
}
