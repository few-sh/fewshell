import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/projects_table.dart';
import 'tables/sessions_table.dart';
import 'tables/messages_table.dart';
import 'tables/snippets_table.dart';

part 'database.g.dart';

/// Main database class for the Decamp app.
/// Uses Drift for type-safe SQL operations and reactive queries.
@DriftDatabase(tables: [Projects, Sessions, Messages, Snippets])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Create indexes for better query performance
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_projects_last_session ON projects(last_session_date DESC)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_projects_name ON projects(name COLLATE NOCASE)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_sessions_project_id ON sessions(project_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_sessions_project_timestamp ON sessions(project_id, timestamp DESC)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages(session_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_messages_session_timestamp ON messages(session_id, created_at ASC)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_snippets_project_id ON snippets(project_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_snippets_name ON snippets(name COLLATE NOCASE)',
        );
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Future migrations will go here
        // Example for version 2:
        // if (from < 2) {
        //   await m.addColumn(projects, projects.newColumn);
        // }
      },
      beforeOpen: (details) async {
        // Enable foreign keys
        await customStatement('PRAGMA foreign_keys = ON');

        if (details.wasCreated) {
          // Seed initial data for development/testing
          await _seedInitialData();
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

/// Opens a connection to the database file
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'decamp.db'));
    return NativeDatabase(file);
  });
}
