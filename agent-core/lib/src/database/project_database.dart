import 'dart:async';
import 'package:drift/drift.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';
import 'package:llm_dart/llm_dart.dart';
import 'package:logging/logging.dart';

import 'tables/sessions_table.dart';
import 'tables/messages_table.dart';
import 'tables/project_snippets_table.dart';
import 'tables/project_saved_prompts_table.dart';
import 'tables/session_mutex_table.dart';
import 'daos/session_dao.dart';
import 'daos/message_dao.dart';
import 'daos/project_snippet_dao.dart';
import 'daos/project_saved_prompt_dao.dart';
import 'daos/session_mutex_dao.dart';
import 'converters/tool_call_converter.dart';

part 'project_database.g.dart';

/// Project-specific database class.
/// Stores Sessions, Messages, and Project Snippets.
@DriftDatabase(tables: [
  Sessions,
  Messages,
  ProjectSnippets,
  ProjectSavedPrompts,
  SessionMutexes
])
class ProjectDatabase extends _$ProjectDatabase {
  final _log = Logger('ProjectDatabase');
  final Crdt? _crdt;
  final Crdt Function()? _crdtProvider;
  StreamSubscription? _crdtSubscription;

  ProjectDatabase(super.e, {Crdt? crdt, Crdt Function()? crdtProvider})
      : _crdt = crdt,
        _crdtProvider = crdtProvider;

  void _setupCrdtListener() {
    if (_crdtSubscription != null) return;

    try {
      final c = crdt;
      if (c is SqliteCrdt) {
        _crdtSubscription = c.onTablesChanged.listen((event) {
          _notifyDriftUpdates(event.tables);
        });
      }
    } catch (_) {
      // Ignore if not ready
    }
  }

  @override
  Future<void> close() {
    _log.info('Closing ProjectDatabase');
    _crdtSubscription?.cancel();
    return super.close();
  }

  void _notifyDriftUpdates(Iterable<String> changedTables) {
    final updates = <TableUpdate>{};
    for (final tableName in changedTables) {
      for (final table in allTables) {
        if (table.actualTableName == tableName) {
          updates.add(TableUpdate.onTable(table));
        }
      }
    }
    if (updates.isNotEmpty) {
      notifyUpdates(updates);
    }
  }

  // DAOs - lazy initialized
  late final SessionDao sessionDao = SessionDao(this);
  late final MessageDao messageDao = MessageDao(this);
  late final ProjectSnippetDao projectSnippetDao = ProjectSnippetDao(this);
  late final SessionMutexDao sessionMutexDao = SessionMutexDao(this);
  late final ProjectSavedPromptDao projectSavedPromptDao =
      ProjectSavedPromptDao(this);

  /// Exposes the underlying CRDT store for sync.
  Crdt get crdt {
    if (_crdt != null) return _crdt;
    if (_crdtProvider != null) return _crdtProvider();
    throw StateError('Database is not running with CrdtQueryExecutor');
  }

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // No-op: Schema upgrades are handled in beforeOpen
      },
      beforeOpen: (details) async {
        // Enable foreign keys
        // TODO: PRAGMA is not supported by SqliteCrdt yet. Need to fork and PR
        // await executor.runCustom('PRAGMA foreign_keys = ON');

        await _reconcileDatabase();

        // Setup CRDT listener now that the DB is open and CRDT should be ready
        _setupCrdtListener();
      },
    );
  }

  Future<void> _reconcileDatabase() async {
    final m = Migrator(this);
    final existingTables = await _getExistingTables();

    for (final table in allTables) {
      if (!existingTables.contains(table.actualTableName)) {
        await m.createTable(table);
      } else {
        final constraintsChanged = await _checkConstraintsChanged(table);
        if (constraintsChanged) {
          _log.info(
              'Recreating table ${table.actualTableName} due to constraint changes');
          await _recreateTable(m, table);
        } else {
          await _reconcileTable(m, table);
        }
      }
    }

    await _createIndexes();
  }

  Future<void> _reconcileTable(Migrator m, TableInfo table) async {
    final existingColumns = await _getExistingColumns(table.actualTableName);

    // Get rid of old is_starred column.
    await _safeDropColumn(m, table, 'is_starred', existingColumns);

    for (final column in table.$columns) {
      await _safeAddColumn(m, table, column, existingColumns);
    }
  }

  Future<void> _safeAddColumn(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
    Set<String> existingColumns,
  ) async {
    if (!existingColumns.contains(column.name)) {
      await m.addColumn(table, column);
    }
  }

  Future<void> _safeDropColumn(
    Migrator m,
    TableInfo table,
    String columnName,
    Set<String> existingColumns,
  ) async {
    if (existingColumns.contains(columnName)) {
      await m.dropColumn(table, columnName);
    }
  }

  Future<Set<String>> _getExistingTables() async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table'",
      readsFrom: {},
    ).get();
    return rows.map((row) => row.read<String>('name')).toSet();
  }

  Future<Set<String>> _getExistingColumns(String tableName) async {
    final rows = await customSelect(
      "SELECT name FROM pragma_table_info('$tableName')",
      readsFrom: {},
    ).get();
    return rows.map((row) => row.read<String>('name')).toSet();
  }

  Future<void> _createIndexes() async {
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_sessions_project_id ON sessions(project_id);',
    );
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_sessions_project_timestamp ON sessions(project_id, timestamp DESC);',
    );
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages(session_id);',
    );
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_messages_session_timestamp ON messages(session_id, created_at ASC);',
    );
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_project_snippets_project_id ON snippets(project_id);',
    );
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_project_snippets_name ON snippets(name COLLATE NOCASE);',
    );
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_project_snippets_position ON snippets(project_id, position ASC);',
    );
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS saved_prompts_project_last_used_idx ON saved_prompts (project_id, last_used_at DESC, created_at DESC)',
    );
  }

  Future<bool> _checkConstraintsChanged(TableInfo table) async {
    final row = await customSelect(
      "SELECT sql FROM sqlite_master WHERE type='table' AND name='${table.actualTableName}'",
      readsFrom: {},
    ).getSingleOrNull();

    if (row == null) return false;
    final currentSql = row.read<String>('sql');

    for (final constraint in table.customConstraints) {
      if (!currentSql.contains(constraint)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _recreateTable(Migrator m, TableInfo table) async {
    final tableName = table.actualTableName;
    final tempName = '${tableName}_backup';

    // 1. Rename existing table
    await executor.runCustom('ALTER TABLE $tableName RENAME TO $tempName');

    // 2. Create new table
    await m.createTable(table);

    // 3. Restore extra columns (CRDT columns etc)
    final oldColumnsInfo = await _getExistingColumnsInfo(tempName);
    final newColumns = table.$columns.map((c) => c.name).toSet();
    final currentNewColumns = await _getExistingColumns(tableName);

    final extraColumns = oldColumnsInfo.where((c) =>
        !newColumns.contains(c.name) &&
        c.name != 'is_starred' && // Explicitly drop is_starred
        !currentNewColumns.contains(c.name));

    for (final col in extraColumns) {
      _log.info('Restoring extra column ${col.name} to $tableName');
      var sql = 'ALTER TABLE $tableName ADD COLUMN ${col.name} ${col.type}';
      if (col.notNull == 1 && col.dfltValue != null) {
        sql += ' DEFAULT ${col.dfltValue}';
      } else if (col.notNull == 1) {
        sql += ' NOT NULL';
      }
      await executor.runCustom(sql);
    }

    // 4. Copy data
    final currentColumns =
        await _getExistingColumns(tableName); // Should be new + extra
    final oldColumnNames = oldColumnsInfo.map((c) => c.name).toSet();
    final commonColumns = currentColumns.intersection(oldColumnNames);

    if (commonColumns.isNotEmpty) {
      final cols = commonColumns.join(', ');
      await executor.runCustom(
          'INSERT INTO $tableName ($cols) SELECT $cols FROM $tempName');
    }

    // 5. Drop old table
    await executor.runCustom('DROP TABLE $tempName');

    // 6. Canonicalize CRDT to restore triggers
    try {
      final c = _crdt ?? (_crdtProvider != null ? _crdtProvider() : null);
      if (c is SqliteCrdt) {
        // Try to call canonicalize dynamically to restore triggers
        await (c as dynamic).canonicalize();
      }
    } catch (e) {
      _log.warning('Failed to canonicalize CRDT after table recreation', e);
    }
  }

  Future<List<PragmaTableInfo>> _getExistingColumnsInfo(
      String tableName) async {
    final rows = await customSelect(
      "SELECT * FROM pragma_table_info('$tableName')",
      readsFrom: {},
    ).get();
    return rows
        .map((row) => PragmaTableInfo(
              name: row.read<String>('name'),
              type: row.read<String>('type'),
              notNull: row.read<int>('notnull'),
              dfltValue: row.read<String?>('dflt_value'),
              pk: row.read<int>('pk'),
            ))
        .toList();
  }
}

class PragmaTableInfo {
  final String name;
  final String type;
  final int notNull;
  final String? dfltValue;
  final int pk;

  PragmaTableInfo({
    required this.name,
    required this.type,
    required this.notNull,
    this.dfltValue,
    required this.pk,
  });
}
