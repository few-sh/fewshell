import 'package:drift/drift.dart';
import 'package:crdt/crdt.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';
import 'package:llm_dart/llm_dart.dart';

import 'tables/sessions_table.dart';
import 'tables/messages_table.dart';
import 'tables/project_snippets_table.dart';
import 'daos/session_dao.dart';
import 'daos/message_dao.dart';
import 'daos/project_snippet_dao.dart';
import 'converters/tool_call_converter.dart';

part 'project_database.g.dart';

/// Project-specific database class.
/// Stores Sessions, Messages, and Project Snippets.
@DriftDatabase(tables: [Sessions, Messages, ProjectSnippets])
class ProjectDatabase extends _$ProjectDatabase {
  final Crdt? _crdt;
  final Crdt Function()? _crdtProvider;

  ProjectDatabase(super.e, {Crdt? crdt, Crdt Function()? crdtProvider})
      : _crdt = crdt,
        _crdtProvider = crdtProvider;

  // DAOs - lazy initialized
  late final SessionDao sessionDao = SessionDao(this);
  late final MessageDao messageDao = MessageDao(this);
  late final ProjectSnippetDao projectSnippetDao = ProjectSnippetDao(this);

  /// Exposes the underlying CRDT store for sync.
  Crdt get crdt {
    if (_crdt != null) return _crdt;
    if (_crdtProvider != null) return _crdtProvider();
    throw StateError('Database is not running with CrdtQueryExecutor');
  }

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Create indexes for better query performance
        await executor.runCustom(
          'CREATE INDEX IF NOT EXISTS idx_sessions_project_id ON sessions(project_id)',
        );
        await executor.runCustom(
          'CREATE INDEX IF NOT EXISTS idx_sessions_project_timestamp ON sessions(project_id, timestamp DESC)',
        );
        await executor.runCustom(
          'CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages(session_id)',
        );
        await executor.runCustom(
          'CREATE INDEX IF NOT EXISTS idx_messages_session_timestamp ON messages(session_id, created_at ASC)',
        );
        await executor.runCustom(
          'CREATE INDEX IF NOT EXISTS idx_project_snippets_project_id ON snippets(project_id)',
        );
        await executor.runCustom(
          'CREATE INDEX IF NOT EXISTS idx_project_snippets_name ON snippets(name COLLATE NOCASE)',
        );
      },
      beforeOpen: (details) async {
        // Enable foreign keys
        await executor.runCustom('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Migration from version 1 to 2: Add position column to project_snippets
        if (from < 2) {
          // Add position column with default value 0
          await m.addColumn(projectSnippets, projectSnippets.position);

          // Initialize positions based on current updatedAt order
          await executor.runCustom('''
            UPDATE snippets 
            SET position = (
              SELECT COUNT(*) 
              FROM snippets s2 
              WHERE s2.project_id = snippets.project_id 
              AND s2.updated_at > snippets.updated_at
            )
          ''');

          // Create index for position ordering
          await executor.runCustom(
            'CREATE INDEX IF NOT EXISTS idx_project_snippets_position ON snippets(project_id, position ASC)',
          );
        }
      },
    );
  }
}
