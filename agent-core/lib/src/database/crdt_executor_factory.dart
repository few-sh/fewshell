import 'dart:async';
import 'package:drift/drift.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';
import 'crdt_executor.dart';
import 'package:logging/logging.dart';

class CrdtExecutorResult {
  final QueryExecutor executor;
  final SqliteCrdt crdt;

  CrdtExecutorResult(this.executor, this.crdt);
}

class CrdtExecutorFactory {
  static final _log = Logger('CrdtExecutorFactory');

  /// Opens a [SqliteCrdt] at [path] and wraps it in a Drift [QueryExecutor].
  ///
  /// The [nodeId] is used as the CRDT identity for **new** (empty) databases.
  /// For existing databases, `SqliteCrdt.open` recovers the node ID from
  /// stored HLC timestamps; use [migrateNodeId] afterward if you need to
  /// change the identity.
  static Future<CrdtExecutorResult> createExecutor(
    String path,
    String nodeId,
  ) async {
    _log.info('Opening SqliteCrdt at $path with nodeId: $nodeId');
    try {
      // Use openInMemory() for in-memory databases to ensure each caller
      // gets a unique SQLite instance (singleInstance defaults to false).
      // SqliteCrdt.open(':memory:') with the default singleInstance=true
      // would return the SAME handle for every caller, causing separate
      // databases (e.g. global vs project) to share one SQLite file.
      final crdt = path == ':memory:'
          ? await SqliteCrdt.openInMemory()
          : await SqliteCrdt.open(path);

      // For a brand-new (empty) DB, SqliteCrdt.open() auto-generated a random
      // node ID via init(). Override it to the requested one so the first
      // records get stamped correctly.
      if (crdt.nodeId != nodeId) {
        final tables = await crdt.getTables();
        final isEmpty = tables.every((t) => t.startsWith('sqlite_'));
        if (isEmpty) {
          // Safe to set directly — no existing HLC timestamps to migrate.
          // ignore: invalid_use_of_protected_member
          crdt.canonicalTime = crdt.canonicalTime.apply(nodeId: nodeId);
          _log.info('Set initial node ID to $nodeId (empty DB)');
        }
      }

      _log.info('SqliteCrdt opened at $path (nodeId: ${crdt.nodeId})');
      final executor = CrdtQueryExecutor(crdt);
      return CrdtExecutorResult(executor, crdt);
    } catch (e, s) {
      _log.severe('Failed to open SqliteCrdt at $path', e, s);
      rethrow;
    }
  }
}
