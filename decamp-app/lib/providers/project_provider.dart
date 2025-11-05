import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../database/database.dart';
import '../database/daos/project_dao.dart';
import 'database_provider.dart';

/// Provider for streaming all projects from the database
final projectsStreamProvider = StreamProvider<List<ProjectEntity>>((ref) {
  final projectDao = ref.watch(projectDaoProvider);
  return projectDao.watchAllProjects();
});

/// StateProvider for the currently selected project ID
final currentProjectIdProvider = StateProvider<String?>((ref) => null);

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

/// Provider for project actions (CRUD operations)
final projectActionsProvider = Provider<ProjectActions>((ref) {
  final projectDao = ref.watch(projectDaoProvider);
  return ProjectActions(projectDao, ref);
});

/// Class containing all project-related actions
class ProjectActions {
  final ProjectDao _projectDao;
  final Ref _ref;

  ProjectActions(this._projectDao, this._ref);

  /// Create a new project
  Future<String> createProject({
    required String name,
    String? description,
  }) async {
    final now = DateTime.now();
    final id = _generateProjectId();

    final companion = ProjectEntityCompanion(
      id: drift.Value(id),
      name: drift.Value(name),
      description: drift.Value(description),
      lastSessionDate: drift.Value(now),
      createdAt: drift.Value(now),
      updatedAt: drift.Value(now),
    );

    await _projectDao.insertProject(companion);
    return id;
  }

  /// Update an existing project
  Future<void> updateProject({
    required String id,
    String? name,
    String? description,
  }) async {
    final companion = ProjectEntityCompanion(
      id: drift.Value(id),
      name: name != null ? drift.Value(name) : const drift.Value.absent(),
      description: description != null
          ? drift.Value(description)
          : const drift.Value.absent(),
      updatedAt: drift.Value(DateTime.now()),
    );

    await _projectDao.updateProject(companion);
  }

  /// Delete a project
  /// Also clears it from currentProjectIdProvider if it was selected
  Future<void> deleteProject(String id) async {
    await _projectDao.deleteProject(id);

    // Clear selection if deleted project was selected
    final currentId = _ref.read(currentProjectIdProvider);
    if (currentId == id) {
      _ref.read(currentProjectIdProvider.notifier).state = null;
    }
  }

  /// Select a project as the current project
  void selectProject(String? id) {
    _ref.read(currentProjectIdProvider.notifier).state = id;
  }

  /// Update the last session date for a project
  Future<void> updateLastSessionDate(String id, DateTime date) async {
    await _projectDao.updateLastSessionDate(id, date);
  }

  /// Search projects by name
  Future<List<ProjectEntity>> searchByName(String query) async {
    return await _projectDao.searchProjectsByName(query);
  }

  /// Get a specific project by ID
  Future<ProjectEntity?> getProject(String id) async {
    return await _projectDao.getProject(id);
  }

  /// Get all projects (non-reactive)
  Future<List<ProjectEntity>> getAllProjects() async {
    return await _projectDao.getAllProjects();
  }

  /// Generate a unique project ID
  String _generateProjectId() {
    return 'proj_${DateTime.now().millisecondsSinceEpoch}_${_randomString(8)}';
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
