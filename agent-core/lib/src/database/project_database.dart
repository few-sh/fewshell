import 'package:drift/drift.dart';
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
  ProjectDatabase(super.e);

  // DAOs - lazy initialized
  late final SessionDao sessionDao = SessionDao(this);
  late final MessageDao messageDao = MessageDao(this);
  late final ProjectSnippetDao snippetDao = ProjectSnippetDao(this);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Create indexes for better query performance
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
        // Migration from version 1 to 2: Add position column to snippets
        if (from < 2) {
          // Add position column with default value 0
          await m.addColumn(projectSnippets, projectSnippets.position);

          // Initialize positions based on current updatedAt order
          // For each project's snippets
          await customStatement('''
            UPDATE snippets 
            SET position = (
              SELECT COUNT(*) 
              FROM snippets s2 
              WHERE s2.project_id = snippets.project_id 
              AND s2.updated_at > snippets.updated_at
            )
            WHERE project_id IS NOT NULL
          ''');

          // Create index for position ordering
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_snippets_position ON snippets(project_id, position ASC)',
          );
        }

        // Migration from version 2 to 3: Add isArchived column to sessions
        if (from < 3) {
          // Add isArchived column with default value false
          await m.addColumn(sessions, sessions.isArchived);

          // Create index for efficient filtering of archived sessions
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sessions_archived ON sessions(project_id, is_archived, timestamp DESC)',
          );
        }

        if (from < 4) {
          // Add discriminated union columns for tool calls and results
          await customStatement('''
        ALTER TABLE messages
        ADD COLUMN message_kind INTEGER NOT NULL DEFAULT 0
      ''');

          await customStatement('''
        ALTER TABLE messages
        ADD COLUMN tool_calls_json TEXT
      ''');

          await customStatement('''
        ALTER TABLE messages
        ADD COLUMN tool_results_json TEXT
      ''');
        }

        // Migration from version 4 to 5: Add editedAt column to messages
        if (from < 5) {
          await m.addColumn(messages, messages.editedAt);
        }
      },
      beforeOpen: (details) async {
        // Enable foreign keys
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
