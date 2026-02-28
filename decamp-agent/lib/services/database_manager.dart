import 'dart:io';
import 'package:agent_core/agent_core.dart';
import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite_crdt/sqlite_crdt.dart';

final _log = Logger('DatabaseManager');

class DatabaseManager {
  late final GlobalDatabase globalDatabase;
  late final String nodeId;
  final Map<String, ProjectDatabase> _projectDatabases = {};
  final String dataPath;

  DatabaseManager(this.dataPath);

  Future<void> init() async {
    final dir = Directory(dataPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Read or generate the persistent server node ID
    nodeId = await readOrCreateNodeId(dataPath);

    final globalDbPath = p.join(dataPath, 'decamp.db');
    final result =
        await CrdtExecutorFactory.createExecutor(globalDbPath, nodeId);
    globalDatabase = GlobalDatabase(result.executor, crdt: result.crdt);

    // Force database initialization to ensure tables exist before sync starts
    await globalDatabase.customStatement('SELECT 1;');

    // Two separate migration concerns:
    // 1. _migrateIfNeeded: migrates internal CRDT HLC timestamps (the
    //    `modified` column) across ALL tables (projects, snippets, etc.).
    //    Without this, old records keep HLCs stamped with 'server' and
    //    CRDT sync could behave incorrectly.
    // 2. _setNodeIdOnProjects: sets the `node_id` DATA column on project
    //    records — the user-facing field clients use for sync filtering
    //    ("which server does this project belong to?").
    await _migrateIfNeeded(result.crdt);
    await _setNodeIdOnProjects();
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
        await CrdtExecutorFactory.createExecutor(projectDbPath, nodeId);
    final db = ProjectDatabase(result.executor, crdt: result.crdt);

    // Force database initialization to ensure tables exist before sync starts
    await db.customStatement('SELECT 1;');

    // Run node ID migration for this project DB
    await _migrateIfNeeded(result.crdt);

    _projectDatabases[projectId] = db;
    return db;
  }

  /// Runs [migrateNodeId] if the CRDT's current node ID differs from [nodeId].
  Future<void> _migrateIfNeeded(SqliteCrdt crdt) async {
    if (crdt.nodeId != nodeId) {
      _log.info('Node ID mismatch: ${crdt.nodeId} → $nodeId, migrating…');
      await migrateNodeId(crdt, nodeId);
    }
  }

  /// Sets the `server_node_id` column on every project record that doesn't
  /// already have the current [nodeId]. This is a normal CRDT write so it
  /// replicates.
  Future<void> _setNodeIdOnProjects() async {
    final projects = await globalDatabase.projectDao.getAllProjects();
    for (final project in projects) {
      if (project.serverNodeId != nodeId) {
        _log.info('Setting server_node_id=$nodeId on project ${project.id}');
        await globalDatabase.projectDao.updateProject(
          ProjectEntityCompanion(
            id: Value(project.id),
            serverNodeId: Value(nodeId),
          ),
        );
      }
    }
  }
}
