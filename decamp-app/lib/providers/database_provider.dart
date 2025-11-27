import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'project_selection_provider.dart';

/// Provider for the GlobalDatabase instance (decamp.db).
final globalDatabaseProvider = Provider<GlobalDatabase>((ref) {
  final database = GlobalDatabase(_openGlobalConnection());

  // Dispose database when provider is disposed
  ref.onDispose(() {
    database.close();
  });

  return database;
});

LazyDatabase _openGlobalConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'decamp.db'));
    return NativeDatabase(file);
  });
}

/// Provider for the ProjectDatabase instance.
/// Returns null if no project is selected.
final projectDatabaseProvider = Provider<ProjectDatabase?>((ref) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) return null;

  final database = ProjectDatabase(_openProjectConnection(projectId));

  // Dispose database when provider is disposed (e.g. project changed)
  ref.onDispose(() {
    database.close();
  });

  return database;
});

LazyDatabase _openProjectConnection(String projectId) {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final projectDir = Directory(p.join(dbFolder.path, 'projects', projectId));
    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
    }
    final file = File(p.join(projectDir.path, 'project.db'));
    return NativeDatabase(file);
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
