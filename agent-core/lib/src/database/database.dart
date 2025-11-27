import 'package:drift/drift.dart';
import 'package:llm_dart/llm_dart.dart';

import 'tables/projects_table.dart';
import 'tables/snippets_table.dart';
import 'daos/project_dao.dart';
import 'daos/snippet_dao.dart';
import 'converters/tool_call_converter.dart';
import 'entities/snippet_entity.dart';

export 'project_database.dart';

part 'database.g.dart';

/// Global database class for the Decamp app.
/// Stores Projects and Global Snippets.
@DriftDatabase(tables: [Projects, Snippets])
class GlobalDatabase extends _$GlobalDatabase {
  GlobalDatabase(super.e);

  // DAOs - lazy initialized
  late final ProjectDao projectDao = ProjectDao(this);
  late final SnippetDao snippetDao = SnippetDao(this);

  @override
  int get schemaVersion => 5;

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
          'CREATE INDEX IF NOT EXISTS idx_snippets_project_id ON snippets(project_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_snippets_name ON snippets(name COLLATE NOCASE)',
        );
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Migration from version 1 to 2: Add position column to snippets
        if (from < 2) {
          // Add position column with default value 0
          await m.addColumn(snippets, snippets.position);

          // Initialize positions based on current updatedAt order
          // For global snippets
          await customStatement('''
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
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_snippets_position ON snippets(project_id, position ASC)',
          );
        }
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
