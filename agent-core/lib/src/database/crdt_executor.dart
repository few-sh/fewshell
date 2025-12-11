import 'dart:async';
import 'package:logging/logging.dart';
import 'package:drift/drift.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';

class CrdtQueryExecutor extends QueryExecutor {
  static final _log = Logger('CrdtQueryExecutor');

  final SqliteCrdt _crdt;
  Completer<void>? _openingCompleter;
  bool _isOpen = false;

  CrdtQueryExecutor(this._crdt);

  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async {
    if (_isOpen) return true;

    // Check if we are already inside the opening process (re-entrant call from migration)
    final isOpening = Zone.current[#isOpening] as bool? ?? false;
    if (isOpening) {
      _log.info('re-entrant open detected, proceeding');
      return true;
    }

    if (_openingCompleter != null) {
      _log.info('waiting for existing open operation');
      await _openingCompleter!.future;
      return true;
    }

    _log.info('ensureOpen');
    _openingCompleter = Completer<void>();

    try {
      await runZoned(() async {
        // Use SELECT from pragma_user_version to avoid ParsingError from sqlparser
        final versionResult =
            await _crdt.query('SELECT * FROM pragma_user_version');
        final currentVersion = (versionResult.first.values.first as int?) ?? 0;
        final db = user as GeneratedDatabase;

        if (currentVersion == 0) {
          await db.beforeOpen(this, OpeningDetails(null, user.schemaVersion));

          final migrator = Migrator(db);
          await db.migration.onCreate(migrator);

          // TODO: PRAGMA is not supported by SqliteCrdt yet. Need to fork and PR
          // await _crdt.execute('PRAGMA user_version = ${user.schemaVersion}');
        } else if (currentVersion < user.schemaVersion) {
          await db.beforeOpen(
            this,
            OpeningDetails(currentVersion, user.schemaVersion),
          );

          final migrator = Migrator(db);
          await db.migration
              .onUpgrade(migrator, currentVersion, user.schemaVersion);

          // await _crdt.execute('PRAGMA user_version = ${user.schemaVersion}');
        } else {
          await db.beforeOpen(
            this,
            OpeningDetails(currentVersion, user.schemaVersion),
          );
        }

        _isOpen = true;
        _openingCompleter!.complete();
      }, zoneValues: {#isOpening: true});

      return true;
    } catch (e, s) {
      _openingCompleter!.completeError(e, s);
      _openingCompleter = null;
      rethrow;
    }
  }

  @override
  Future<void> runBatched(BatchedStatements statements) async {
    _log.info('runBatched ${statements.statements.length} statements');
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
    _log.info('runCustom $statement args: $args');
    return _crdt.execute(statement, args ?? const []);
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) async {
    _log.info('runDelete $statement args: $args');
    await _crdt.execute(statement, args);
    final result = await _crdt.query('SELECT changes()');
    return (result.first.values.first as int?) ?? 0;
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) async {
    _log.info('runInsert $statement args: $args');
    await _crdt.execute(statement, args);
    final result = await _crdt.query('SELECT last_insert_rowid()');
    return (result.first.values.first as int?) ?? 0;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) {
    _log.info('runSelect $statement args: $args');
    return _crdt.query(statement, args);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async {
    _log.info('runUpdate $statement args: $args');
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
    _log.info('beginTransaction');
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
