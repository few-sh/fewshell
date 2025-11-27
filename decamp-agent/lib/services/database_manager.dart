import 'dart:io';
import 'package:agent_core/agent_core.dart';
import 'package:path/path.dart' as p;

class DatabaseManager {
  late final GlobalDatabase globalDatabase;
  final Map<String, ProjectDatabase> _projectDatabases = {};
  final String dataPath;

  DatabaseManager(this.dataPath);

  Future<void> init() async {
    final dir = Directory(dataPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final globalDbPath = p.join(dataPath, 'decamp.db');
    // Server node ID is 'server'
    final result =
        await CrdtExecutorFactory.createExecutor(globalDbPath, 'server');
    globalDatabase = GlobalDatabase(result.executor, crdt: result.crdt);
  }

  Future<ProjectDatabase> getProjectDatabase(String projectId) async {
    if (_projectDatabases.containsKey(projectId)) {
      return _projectDatabases[projectId]!;
    }

    final projectDbPath = p.join(dataPath, 'projects', projectId, 'project.db');
    final dir = Directory(p.dirname(projectDbPath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final result =
        await CrdtExecutorFactory.createExecutor(projectDbPath, 'server');
    final db = ProjectDatabase(result.executor, crdt: result.crdt);
    _projectDatabases[projectId] = db;
    return db;
  }
}
