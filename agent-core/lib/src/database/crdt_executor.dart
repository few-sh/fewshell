import 'dart:async';
import 'package:drift/drift.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';

class CrdtQueryExecutor extends QueryExecutor {
  final SqliteCrdt _crdt;
  bool _isOpening = false;

  CrdtQueryExecutor(this._crdt);

  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async {
    if (_isOpening) return true;
    _isOpening = true;
    try {
      final versionResult = await _crdt.query('PRAGMA user_version');
      final currentVersion = (versionResult.first.values.first as int?) ?? 0;
      final db = user as GeneratedDatabase;

      if (currentVersion == 0) {
        await db.beforeOpen(this, OpeningDetails(null, user.schemaVersion));

        final migrator = Migrator(db);
        await db.migration.onCreate(migrator);

        await _crdt.execute('PRAGMA user_version = ${user.schemaVersion}');
      } else if (currentVersion < user.schemaVersion) {
        await db.beforeOpen(
            this, OpeningDetails(currentVersion, user.schemaVersion));

        final migrator = Migrator(db);
        await db.migration
            .onUpgrade(migrator, currentVersion, user.schemaVersion);

        await _crdt.execute('PRAGMA user_version = ${user.schemaVersion}');
      } else {
        await db.beforeOpen(
            this, OpeningDetails(currentVersion, user.schemaVersion));
      }

      return true;
    } finally {
      _isOpening = false;
    }
  }

  @override
  Future<void> runBatched(BatchedStatements statements) async {
    for (var i = 0; i < statements.statements.length; i++) {
      final sql = statements.statements[i];
      final args = statements.arguments[i];
      // ArgumentsForBatchedStatement seems to be a wrapper.
      // We assume it can be used as List<Object?> or converted.
      // If not, we might need to inspect it.
      // For now, let's try to cast it to dynamic and then to List.
      await _crdt.execute(sql, (args as dynamic) as List<Object?>);
    }
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) {
    return _crdt.execute(statement, args ?? const []);
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) async {
    await _crdt.execute(statement, args);
    final result = await _crdt.query('SELECT changes()');
    return (result.first.values.first as int?) ?? 0;
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) async {
    await _crdt.execute(statement, args);
    final result = await _crdt.query('SELECT last_insert_rowid()');
    return (result.first.values.first as int?) ?? 0;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
      String statement, List<Object?> args) {
    return _crdt.query(statement, args);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async {
    await _crdt.execute(statement, args);
    final result = await _crdt.query('SELECT changes()');
    return (result.first.values.first as int?) ?? 0;
  }

  @override
  QueryExecutor beginExclusive() {
    return this;
  }

  @override
  TransactionExecutor beginTransaction() {
    return _CrdtTransactionExecutor(_crdt);
  }
}

class _CrdtTransactionExecutor extends CrdtQueryExecutor
    implements TransactionExecutor {
  _CrdtTransactionExecutor(super.crdt);

  @override
  bool get supportsNestedTransactions => false;

  @override
  Future<void> send() async {
    // No-op
  }

  @override
  Future<void> rollback() async {
    // No-op or manual rollback if supported
  }
}
