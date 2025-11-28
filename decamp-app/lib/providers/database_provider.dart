import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:crdt/crdt.dart';
import 'project_selection_provider.dart';
import 'theme_provider.dart';
import 'package:agent_core/src/database/database_facade.dart';

// Registry to hold Crdt instances
final crdtRegistry = <String, Crdt>{};

final nodeIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  var nodeId = prefs.getString('node_id');
  if (nodeId == null) {
    nodeId = const Uuid().v4();
    prefs.setString('node_id', nodeId);
  }
  return nodeId;
});

/// Provider for the GlobalDatabase instance (decamp.db).
final globalDatabaseProvider = Provider<GlobalDatabase>((ref) {
  final nodeId = ref.watch(nodeIdProvider);
  final database = GlobalDatabase(
    _openGlobalConnection(nodeId),
    crdtProvider: () => crdtRegistry['global']!,
  );

  // Dispose database when provider is disposed
  ref.onDispose(() {
    database.close();
  });

  return database;
});

LazyDatabase _openGlobalConnection(String nodeId) {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final path = p.join(dbFolder.path, 'decamp.db');

    final result = await CrdtExecutorFactory.createExecutor(path, nodeId);
    crdtRegistry['global'] = result.crdt;
    return result.executor;
  });
}

/// Provider for the ProjectDatabase instance.
/// Returns null if no project is selected.
final projectDatabaseProvider = Provider<ProjectDatabase?>((ref) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) return null;

  final nodeId = ref.watch(nodeIdProvider);

  final database = ProjectDatabase(
    _openProjectConnection(projectId, nodeId),
    crdtProvider: () => crdtRegistry[projectId]!,
  );

  // Dispose database when provider is disposed (e.g. project changed)
  ref.onDispose(() {
    database.close();
    crdtRegistry.remove(projectId);
  });

  return database;
});

LazyDatabase _openProjectConnection(String projectId, String nodeId) {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final projectDir = Directory(p.join(dbFolder.path, 'projects', projectId));
    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
    }
    final path = p.join(projectDir.path, 'project.db');

    final result = await CrdtExecutorFactory.createExecutor(path, nodeId);
    crdtRegistry[projectId] = result.crdt;
    return result.executor;
  });
}

/// Provider for the DatabaseFacade.
/// This replaces the old databaseProvider.
/// Access DAOs directly: ref.watch(databaseProvider).projectDao
final databaseProvider = Provider<DatabaseFacade>((ref) {
  final globalDb = ref.watch(globalDatabaseProvider);
  final projectDb = ref.watch(projectDatabaseProvider);
  final projectId = ref.watch(currentProjectIdProvider);

  return DatabaseFacade(globalDb, projectDb, projectId);
});
