import 'dart:async';
import 'package:drift/drift.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';

import 'tables/projects_table.dart';
import 'tables/snippets_table.dart';
import 'tables/saved_prompts_table.dart';
import 'daos/project_dao.dart';
import 'daos/snippet_dao.dart';
import 'daos/saved_prompt_dao.dart';
import 'entities/snippet_entity.dart';
import 'entities/saved_prompt_entity.dart';

export 'project_database.dart';
export 'crdt_executor_factory.dart';

part 'database.g.dart';

/// Global database class for the Decamp app.
/// Stores Projects and Global Snippets.
@DriftDatabase(tables: [Projects, Snippets, SavedPrompts])
class GlobalDatabase extends _$GlobalDatabase {
  final Crdt? _crdt;
  final Crdt Function()? _crdtProvider;
  StreamSubscription? _crdtSubscription;

  GlobalDatabase(super.e, {Crdt? crdt, Crdt Function()? crdtProvider})
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
  late final ProjectDao projectDao = ProjectDao(this);
  late final SnippetDao snippetDao = SnippetDao(this);
  late final SavedPromptDao savedPromptDao = SavedPromptDao(this);

  /// Exposes the underlying CRDT store for sync.
  Crdt get crdt {
    if (_crdt != null) return _crdt;
    if (_crdtProvider != null) return _crdtProvider();
    throw StateError('Database is not running with CrdtQueryExecutor');
  }

  @override
  int get schemaVersion => 9;

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

        if (details.wasCreated) {
          // Seed initial data for development/testing
          await _seedInitialData();
        }
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
        await _reconcileTable(m, table);
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
      'CREATE INDEX IF NOT EXISTS idx_projects_last_session ON projects(last_session_date DESC);',
    );
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_projects_name ON projects(name COLLATE NOCASE);',
    );
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_snippets_project_id ON snippets(project_id);',
    );
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_snippets_name ON snippets(name COLLATE NOCASE);',
    );
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_snippets_position ON snippets(project_id, position ASC);',
    );
  }

  /// Seeds initial data for development/testing
  Future<void> _seedInitialData() async {
    // This can be used to add sample data during development
    // Leave empty for production
  }
}
