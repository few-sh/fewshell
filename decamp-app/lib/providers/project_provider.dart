import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import 'database_provider.dart';
import 'theme_provider.dart';

/// Key for storing current project ID in SharedPreferences
const String _currentProjectIdKey = 'current_project_id';

/// Provider for streaming all projects from the database
final projectsStreamProvider = StreamProvider<List<ProjectEntity>>((ref) {
  final projectDao = ref.watch(projectDaoProvider);
  return projectDao.watchAllProjects();
});

/// StateProvider for the currently selected project ID
/// Initialized from SharedPreferences on first access
final currentProjectIdProvider = StateProvider<String?>((ref) {
  // Load from SharedPreferences on initialization
  final prefs = ref.watch(sharedPreferencesProvider);
  final savedProjectId = prefs.getString(_currentProjectIdKey);
  return savedProjectId;
});

/// Provider for the currently selected project
/// Returns null if no project is selected or project doesn't exist
final currentProjectProvider = Provider<ProjectEntity?>((ref) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) return null;

  final projectsAsync = ref.watch(projectsStreamProvider);
  return projectsAsync.whenData((projects) {
    try {
      return projects.firstWhere((p) => p.id == projectId);
    } catch (e) {
      return null;
    }
  }).value;
});

/// Helper functions for project operations with side effects

/// Select a project as the current project
/// Persists the selection to SharedPreferences
Future<void> selectProject(WidgetRef ref, String? id) async {
  ref.read(currentProjectIdProvider.notifier).state = id;

  // Persist to SharedPreferences
  final prefs = ref.read(sharedPreferencesProvider);
  if (id != null) {
    await prefs.setString(_currentProjectIdKey, id);
  } else {
    await prefs.remove(_currentProjectIdKey);
  }
}

/// Delete a project and clear selection if it was selected
Future<void> deleteProject(WidgetRef ref, String id) async {
  final projectDao = ref.read(databaseProvider).projectDao;
  await projectDao.deleteProject(id);

  // Clear selection if deleted project was selected
  final currentId = ref.read(currentProjectIdProvider);
  if (currentId == id) {
    await selectProject(ref, null);
  }
}

/// Update an existing project
Future<void> updateProject(
  WidgetRef ref, {
  required String id,
  String? name,
  String? description,
}) async {
  final projectDao = ref.read(databaseProvider).projectDao;
  
  final companion = ProjectEntityCompanion(
    id: Value(id),
    name: name != null ? Value(name) : const Value.absent(),
    description: description != null ? Value(description) : const Value.absent(),
    updatedAt: Value(DateTime.now()),
  );

  await projectDao.updateProject(companion);
}
