import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:agent_core/agent_core.dart';
import '../providers/database_provider.dart';

/// Stream provider for global saved prompts
final globalSavedPromptsProvider = StreamProvider<List<SavedPromptEntity>>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  return db.savedPromptDao.watchGlobalSavedPrompts();
});

/// Stream provider for project saved prompts (family provider)
final projectSavedPromptsProvider =
    StreamProvider.family<List<SavedPromptEntity>, String>((ref, projectId) {
      final db = ref.watch(databaseProvider);
      return db.savedPromptDao.watchProjectSavedPrompts(projectId);
    });

/// Controller for saved prompt mutations
class SavedPromptController {
  final Ref _ref;

  SavedPromptController(this._ref);

  Future<void> addSavedPrompt({
    required String content,
    String? description,
    List<String> tags = const [],
    String? projectId,
  }) async {
    final db = _ref.read(databaseProvider);
    final now = DateTime.now();

    final savedPrompt = SavedPromptEntityCompanion(
      id: Value(_generateSavedPromptId()),
      projectId: Value(projectId),
      content: Value(content),
      description: Value(description),
      tags: Value(tags.join(',')),
      createdAt: Value(now),
      updatedAt: Value(now),
      lastUsedAt: Value(now),
    );

    await db.savedPromptDao.insertSavedPrompt(savedPrompt);
  }

  Future<void> updateSavedPrompt({
    required String id,
    String? content,
    String? description,
    List<String>? tags,
  }) async {
    final db = _ref.read(databaseProvider);
    final savedPrompt = SavedPromptEntityCompanion(
      id: Value(id),
      content: content != null ? Value(content) : const Value.absent(),
      description: description != null
          ? Value(description)
          : const Value.absent(),
      tags: tags != null ? Value(tags.join(',')) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );

    await db.savedPromptDao.updateSavedPrompt(savedPrompt);
  }

  Future<void> deleteSavedPrompt(String id) async {
    final db = _ref.read(databaseProvider);
    await db.savedPromptDao.deleteSavedPrompt(id);
  }

  Future<void> markAsUsed(String id) async {
    final db = _ref.read(databaseProvider);
    final savedPrompt = SavedPromptEntityCompanion(
      id: Value(id),
      lastUsedAt: Value(DateTime.now()),
    );
    await db.savedPromptDao.updateSavedPrompt(savedPrompt);
  }

  String _generateSavedPromptId() => IdGenerator.savedPromptId();
}

final savedPromptControllerProvider = Provider(
  (ref) => SavedPromptController(ref),
);
