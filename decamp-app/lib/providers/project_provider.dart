import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_provider.dart';
import 'theme_provider.dart';
import 'session_provider.dart';

/// Provider for streaming all projects from the database
/// OPTIMIZED: Depends only on Global DB. Does not rebuild when selection changes.
final projectsStreamProvider = StreamProvider<List<ProjectEntity>>((ref) {
  final globalDb = ref.watch(globalDatabaseProvider);
  return globalDb.projectDao.watchAllProjects();
});

/// StateNotifier for the currently selected project ID
class SelectedProjectNotifier extends StateNotifier<String?> {
  final SharedPreferences _prefs;
  final Ref _ref;
  static const _key = 'current_project_id';

  SelectedProjectNotifier(this._prefs, this._ref)
    : super(_prefs.getString(_key));

  Future<void> select(String? id) async {
    state = id;
    if (id != null) {
      await _prefs.setString(_key, id);
      // Trigger session selection logic
      await _ref.read(sessionControllerProvider).ensureSessionSelected(id);
    } else {
      await _prefs.remove(_key);
      _ref.read(currentSessionIdProvider.notifier).state = null;
    }
  }
}

/// Provider for the currently selected project ID
/// CONSOLIDATED: Selection state + Persistence logic in one place.
final currentProjectIdProvider =
    StateNotifierProvider<SelectedProjectNotifier, String?>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return SelectedProjectNotifier(prefs, ref);
    });

/// Provider for the currently selected project
/// SIMPLIFIED: Derived state
final currentProjectProvider = Provider<ProjectEntity?>((ref) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) return null;

  return ref
      .watch(projectsStreamProvider)
      .whenOrNull(
        data: (projects) {
          try {
            return projects.firstWhere((p) => p.id == projectId);
          } catch (e) {
            return null;
          }
        },
      );
});

/// Controller for project actions
class ProjectController {
  final Ref _ref;
  ProjectController(this._ref);

  Future<void> deleteProject(String id) async {
    final globalDb = _ref.read(globalDatabaseProvider);
    await globalDb.projectDao.deleteProject(id);

    // Auto-deselect if we deleted the active project
    if (_ref.read(currentProjectIdProvider) == id) {
      _ref.read(currentProjectIdProvider.notifier).select(null);
    }
  }

  Future<void> updateProject({
    required String id,
    String? name,
    String? description,
    Value<String?> serverUrl = const Value.absent(),
  }) async {
    final globalDb = _ref.read(globalDatabaseProvider);

    final companion = ProjectEntityCompanion(
      id: Value(id),
      name: name != null ? Value(name) : const Value.absent(),
      description: description != null
          ? Value(description)
          : const Value.absent(),
      serverUrl: serverUrl,
      updatedAt: Value(DateTime.now()),
    );

    await globalDb.projectDao.updateProject(companion);
  }
}

/// Provider for the ProjectController
final projectControllerProvider = Provider((ref) => ProjectController(ref));
