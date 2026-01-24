import 'dart:io';
import 'package:agent_core/agent_core.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:crdt/crdt.dart';
import 'package:logging/logging.dart';

final _log = Logger('DatabaseProvider');

/// Helper function to open global database connection
/// Used by providers.dart
LazyDatabase openGlobalConnection(
  String nodeId,
  void Function(Crdt) onCrdtCreated,
) {
  return LazyDatabase(() async {
    _log.info('Opening global database connection...');
    final dbFolder = await getApplicationDocumentsDirectory();
    final path = p.join(dbFolder.path, 'decamp.db');
    _log.info('Global DB path: $path');

    final result = await CrdtExecutorFactory.createExecutor(path, nodeId);
    onCrdtCreated(result.crdt);
    return result.executor;
  });
}

/// Helper function to open project database connection
/// Used by providers.dart
LazyDatabase openProjectConnection(
  String projectId,
  String nodeId,
  void Function(Crdt) onCrdtCreated,
) {
  return LazyDatabase(() async {
    _log.info('Opening project database connection for $projectId...');
    final dbFolder = await getApplicationDocumentsDirectory();
    final projectDir = Directory(p.join(dbFolder.path, 'projects', projectId));
    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
    }
    final path = p.join(projectDir.path, 'project.db');
    _log.info('Project DB path: $path');

    final result = await CrdtExecutorFactory.createExecutor(path, nodeId);
    onCrdtCreated(result.crdt);
    return result.executor;
  });
}
