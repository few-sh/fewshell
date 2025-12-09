import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:agent_core/agent_core.dart';
import '../providers/database_provider.dart';

/// Stream provider for global snippets
final globalSnippetsProvider = StreamProvider<List<SnippetEntity>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.snippetDao.watchGlobalSnippets();
});

/// Stream provider for project snippets (family provider)
final projectSnippetsProvider =
    StreamProvider.family<List<SnippetEntity>, String>((ref, projectId) {
      final db = ref.watch(databaseProvider);
      return db.snippetDao.watchProjectSnippets(projectId);
    });

/// Controller for snippet mutations
class SnippetController {
  final Ref _ref;

  SnippetController(this._ref);

  Future<void> addSnippet({
    required String name,
    required String content,
    String? description,
    List<String> tags = const [],
    String? projectId,
  }) async {
    final db = _ref.read(databaseProvider);
    final now = DateTime.now();

    // Get the next position (max + 1)
    final maxPosition = await db.snippetDao.getMaxPosition(
      projectId: projectId,
    );
    final nextPosition = maxPosition + 1;

    final snippet = SnippetEntityCompanion(
      id: Value(_generateSnippetId()),
      projectId: Value(projectId),
      name: Value(name),
      content: Value(content),
      description: Value(description),
      tags: Value(tags.join(',')),
      position: Value(nextPosition),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await db.snippetDao.insertSnippet(snippet);
  }

  Future<void> updateSnippet({
    required String id,
    String? name,
    String? content,
    String? description,
    List<String>? tags,
  }) async {
    final db = _ref.read(databaseProvider);
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

    await db.snippetDao.updateSnippet(snippet);
  }

  Future<void> deleteSnippet(String id) async {
    final db = _ref.read(databaseProvider);
    await db.snippetDao.deleteSnippet(id);
  }

  Future<void> reorderSnippets(
    List<SnippetEntity> snippets,
    int oldIndex,
    int newIndex,
  ) async {
    final db = _ref.read(databaseProvider);
    final reordered = List<SnippetEntity>.from(snippets);

    // Adjust newIndex if moving down
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final snippet = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, snippet);

    // Update position values for all snippets in the new order
    for (int i = 0; i < reordered.length; i++) {
      await db.snippetDao.updateSnippet(
        SnippetEntityCompanion(id: Value(reordered[i].id), position: Value(i)),
      );
    }
  }

  String _generateSnippetId() => IdGenerator.snippetId();
}

final snippetControllerProvider = Provider((ref) => SnippetController(ref));
