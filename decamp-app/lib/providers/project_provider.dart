import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:agent_core/agent_core.dart';
import 'database_provider.dart';
import 'project_selection_provider.dart';

/// Provider for streaming all projects from the database
final projectsStreamProvider = StreamProvider<List<ProjectEntity>>((ref) {
  final projectDao = ref.watch(databaseProvider).projectDao;
  return projectDao.watchAllProjects();
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
  Value<String?> serverUrl = const Value.absent(),
}) async {
  final projectDao = ref.read(databaseProvider).projectDao;

  final companion = ProjectEntityCompanion(
    id: Value(id),
    name: name != null ? Value(name) : const Value.absent(),
    description: description != null
        ? Value(description)
        : const Value.absent(),
    serverUrl: serverUrl,
    updatedAt: Value(DateTime.now()),
  );

  await projectDao.updateProject(companion);
}
