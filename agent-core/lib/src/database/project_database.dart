import 'dart:async';
import 'package:drift/drift.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';
import 'package:llm_dart/llm_dart.dart';

import 'tables/sessions_table.dart';
import 'tables/messages_table.dart';
import 'tables/project_snippets_table.dart';
import 'tables/session_mutex_table.dart';
import 'daos/session_dao.dart';
import 'daos/message_dao.dart';
import 'daos/project_snippet_dao.dart';
import 'daos/session_mutex_dao.dart';
import 'converters/tool_call_converter.dart';

part 'project_database.g.dart';

/// Project-specific database class.
/// Stores Sessions, Messages, and Project Snippets.
@DriftDatabase(tables: [Sessions, Messages, ProjectSnippets, SessionMutexes])
class ProjectDatabase extends _$ProjectDatabase {
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

  /// Exposes the underlying CRDT store for sync.
  Crdt get crdt {
    if (_crdt != null) return _crdt;
    if (_crdtProvider != null) return _crdtProvider();
    throw StateError('Database is not running with CrdtQueryExecutor');
  }

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Create indexes for better query performance
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
      },
      beforeOpen: (details) async {
        // Enable foreign keys
        // TODO: PRAGMA is not supported by SqliteCrdt yet. Need to fork and PR
        // await executor.runCustom('PRAGMA foreign_keys = ON');

        // Setup CRDT listener now that the DB is open and CRDT should be ready
        _setupCrdtListener();
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
            );
          ''');

          // Create index for position ordering
          await executor.runCustom(
            'CREATE INDEX IF NOT EXISTS idx_project_snippets_position ON snippets(project_id, position ASC);',
          );
        }

        // Migration from version 6 to 7: Add isStreaming column to messages
        if (from < 7) {
          // Check if column already exists to handle potential partial migrations
          // Use SELECT from pragma_table_info to avoid ParsingError from sqlparser
          final columns = await executor
              .runSelect("SELECT * FROM pragma_table_info('messages');", []);
          final hasIsStreaming =
              columns.any((row) => row['name'] == 'is_streaming');

          if (!hasIsStreaming) {
            await m.addColumn(messages, messages.isStreaming);
          }
        }

        // Migration from version 7 to 8: Add isStarred column to sessions (Removed)
        if (from < 8) {
          // isStarred column was removed in invalidation plan
        }

        // Migration from version 8 to 9: Add isVisibleToLlm column to messages
        if (from < 9) {
          final columns = await executor
              .runSelect("SELECT * FROM pragma_table_info('messages');", []);
          final hasIsVisibleToLlm =
              columns.any((row) => row['name'] == 'is_visible_to_llm');

          if (!hasIsVisibleToLlm) {
            await m.addColumn(messages, messages.isVisibleToLlm);
          }
        }

        // Migration from version 9 to 10: Add isVisibleToLlm column to snippets
        if (from < 10) {
          final columns = await executor
              .runSelect("SELECT * FROM pragma_table_info('snippets');", []);
          final hasIsVisibleToLlm =
              columns.any((row) => row['name'] == 'is_visible_to_llm');

          if (!hasIsVisibleToLlm) {
            await m.addColumn(projectSnippets, projectSnippets.isVisibleToLlm);
          }
        }

        // Migration from version 11 to 12: Add session_mutexes table
        if (from < 11) {
          await m.createTable(sessionMutexes);
        }
      },
    );
  }
}
