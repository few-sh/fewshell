import 'dart:async';
import 'package:drift/drift.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';

import 'tables/projects_table.dart';
import 'tables/snippets_table.dart';
import 'daos/project_dao.dart';
import 'daos/snippet_dao.dart';
import 'entities/snippet_entity.dart';

export 'project_database.dart';
export 'crdt_executor_factory.dart';

part 'database.g.dart';

/// Global database class for the Decamp app.
/// Stores Projects and Global Snippets.
@DriftDatabase(tables: [Projects, Snippets])
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

  /// Exposes the underlying CRDT store for sync.
  Crdt get crdt {
    if (_crdt != null) return _crdt;
    if (_crdtProvider != null) return _crdtProvider();
    throw StateError('Database is not running with CrdtQueryExecutor');
  }

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Create indexes for better query performance
        await executor.runCustom(
          'CREATE INDEX IF NOT EXISTS idx_projects_last_session ON projects(last_session_date DESC)',
        );
        await executor.runCustom(
          'CREATE INDEX IF NOT EXISTS idx_projects_name ON projects(name COLLATE NOCASE)',
        );
        await executor.runCustom(
          'CREATE INDEX IF NOT EXISTS idx_snippets_project_id ON snippets(project_id)',
        );
        await executor.runCustom(
          'CREATE INDEX IF NOT EXISTS idx_snippets_name ON snippets(name COLLATE NOCASE)',
        );
      },
      beforeOpen: (details) async {
        // Enable foreign keys
        // TODO: PRAGMA is not supported by SqliteCrdt yet. Need to fork and PR
        // await executor.runCustom('PRAGMA foreign_keys = ON');

        // Setup CRDT listener now that the DB is open and CRDT should be ready
        _setupCrdtListener();

        if (details.wasCreated) {
          // Seed initial data for development/testing
          await _seedInitialData();
        }
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Migration from version 1 to 2: Add position column to snippets
        if (from < 2) {
          // Add position column with default value 0
          await m.addColumn(snippets, snippets.position);

          // Initialize positions based on current updatedAt order
          // For global snippets
          await executor.runCustom('''
            UPDATE snippets 
            SET position = (
              SELECT COUNT(*) 
              FROM snippets s2 
              WHERE s2.project_id IS NULL 
              AND s2.updated_at > snippets.updated_at
            )
            WHERE project_id IS NULL
          ''');

          // Create index for position ordering
          await executor.runCustom(
            'CREATE INDEX IF NOT EXISTS idx_snippets_position ON snippets(project_id, position ASC)',
          );
        }

        // Migration from version 5 to 6: Add serverUrl column to projects
        if (from < 6) {
          await m.addColumn(projects, projects.serverUrl);
        }
      },
    );
  }

  /// Seeds initial data for development/testing
  Future<void> _seedInitialData() async {
    // This can be used to add sample data during development
    // Leave empty for production
  }
}
