import 'package:agent_core/agent_core.dart' as core;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../utils/id_generator.dart';
import '../providers/database_provider.dart';
import '../providers/remote_data_provider.dart';

/// Stream provider for global snippets
final globalSnippetsProvider = StreamProvider<List<SnippetEntity>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.snippetDao.watchGlobalSnippets();
});

/// Stream provider for project snippets (family provider)
/// For remote projects, this fetches from the server instead of local DB
final projectSnippetsProvider =
    StreamProvider.family<List<SnippetEntity>, String>((ref, projectId) {
      final db = ref.watch(databaseProvider);
      return db.snippetDao.watchProjectSnippets(projectId);
    });

/// Helper functions for snippet mutations
/// Call these directly from UI instead of using unnecessary StateNotifier layer
/// These automatically route to remote server for remote projects

/// Add a new snippet
Future<void> addSnippet(
  WidgetRef ref, {
  required String name,
  required String content,
  String? description,
  List<String> tags = const [],
  String? projectId,
}) async {
  final now = DateTime.now();
  final id = _generateSnippetId();

  // Check if this is a remote project
  final isRemote = ref.read(isRemoteProjectProvider);
  if (isRemote && projectId != null) {
    final controller = ref.read(remoteControllerProvider);
    if (controller != null) {
      final snippet = core.Snippet(
        id: id,
        projectId: projectId,
        name: name,
        content: content,
        description: description,
        tags: tags,
        position: 0, // Server will handle position
        createdAt: now,
        updatedAt: now,
      );
      await controller.saveSnippet(snippet);
      // Invalidate remote snippets to refresh
      ref.invalidate(remoteSnippetsProvider);
      return;
    }
  }

  // Local storage
  final db = ref.read(databaseProvider);
  final maxPosition = await db.snippetDao.getMaxPosition(projectId: projectId);
  final nextPosition = maxPosition + 1;

  final snippet = SnippetEntityCompanion(
    id: Value(id),
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

/// Update an existing snippet
Future<void> updateSnippet(
  WidgetRef ref, {
  required String id,
  String? projectId,
  String? name,
  String? content,
  String? description,
  List<String>? tags,
}) async {
  // Check if this is a remote project
  final isRemote = ref.read(isRemoteProjectProvider);
  if (isRemote && projectId != null) {
    final controller = ref.read(remoteControllerProvider);
    if (controller != null) {
      // For remote, we need to send the full snippet
      // Fetch existing first to merge changes
      final snippets = await controller.getSnippets();
      final existing = snippets.where((s) => s.id == id).firstOrNull;
      if (existing != null) {
        final updated = existing.copyWith(
          name: name ?? existing.name,
          content: content ?? existing.content,
          description: description ?? existing.description,
          tags: tags ?? existing.tags,
          updatedAt: DateTime.now(),
        );
        await controller.saveSnippet(updated);
        ref.invalidate(remoteSnippetsProvider);
      }
      return;
    }
  }

  // Local storage
  final db = ref.read(databaseProvider);
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

/// Delete a snippet
Future<void> deleteSnippet(
  WidgetRef ref,
  String id, {
  String? projectId,
}) async {
  // Check if this is a remote project
  final isRemote = ref.read(isRemoteProjectProvider);
  if (isRemote && projectId != null) {
    final controller = ref.read(remoteControllerProvider);
    if (controller != null) {
      await controller.deleteSnippet(id);
      ref.invalidate(remoteSnippetsProvider);
      return;
    }
  }

  // Local storage
  final db = ref.read(databaseProvider);
  await db.snippetDao.deleteSnippet(id);
}

/// Reorder snippets (updates position values)
Future<void> reorderSnippets(
  WidgetRef ref,
  List<SnippetEntity> snippets,
  int oldIndex,
  int newIndex,
) async {
  final db = ref.read(databaseProvider);
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

/// Generate a unique snippet ID
String _generateSnippetId() => IdGenerator.snippetId();
