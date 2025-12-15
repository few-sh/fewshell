import 'dart:async';
import 'package:drift/drift.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';
import 'crdt_executor.dart';
import 'package:logging/logging.dart';

class CrdtExecutorResult {
  final QueryExecutor executor;
  final Crdt crdt;

  CrdtExecutorResult(this.executor, this.crdt);
}

class CrdtExecutorFactory {
  static final _log = Logger('CrdtExecutorFactory');

  static Future<CrdtExecutorResult> createExecutor(
    String path,
    String nodeId,
  ) async {
    _log.info('Opening SqliteCrdt at $path with nodeId: $nodeId');
    try {
      final crdt = await SqliteCrdt.open(path);
      _log.info('SqliteCrdt opened successfully at $path');
      // Note: SqliteCrdt manages nodeId internally or generates it.
      // If we need to set it explicitly, we might need to check SqliteCrdt API.

      final executor = CrdtQueryExecutor(crdt);
      return CrdtExecutorResult(executor, crdt);
    } catch (e, s) {
      _log.severe('Failed to open SqliteCrdt at $path', e, s);
      rethrow;
    }
  }
}
