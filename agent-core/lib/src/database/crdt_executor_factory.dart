import 'dart:async';
import 'package:drift/drift.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';
import 'crdt_executor.dart';

class CrdtExecutorResult {
  final QueryExecutor executor;
  final Crdt crdt;

  CrdtExecutorResult(this.executor, this.crdt);
}

class CrdtExecutorFactory {
  static Future<CrdtExecutorResult> createExecutor(
    String path,
    String nodeId,
  ) async {
    final crdt = await SqliteCrdt.open(path);
    // Note: SqliteCrdt manages nodeId internally or generates it.
    // If we need to set it explicitly, we might need to check SqliteCrdt API.

    final executor = CrdtQueryExecutor(crdt);
    return CrdtExecutorResult(executor, crdt);
  }
}
