import 'dart:io';

import 'package:sqlite3/sqlite3.dart' hide Session;

import '../models/message.dart';
import '../models/session.dart';
import 'session_store.dart';

/// SQLite implementation of SessionStore.
///
/// This is used by both:
/// - decamp-agent (server): stores in ~/.decamp/server.db
/// - decamp-app (local projects): stores in app's documents directory
///
/// For Flutter apps, use the sqlite3_flutter_libs package to provide
/// the native SQLite library.
class SqliteSessionStore implements SessionStore {
  final Database _db;

  SqliteSessionStore._(this._db);

  /// Open or create the database at the given path
  static SqliteSessionStore open(String path) {
    // Ensure directory exists
    final dir = Directory(path).parent;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final db = sqlite3.open(path);
    final store = SqliteSessionStore._(db);
    store._initialize();
    return store;
  }

  /// Open with default server path (~/.decamp/server.db)
  /// Use this for the decamp-agent server.
  static SqliteSessionStore openServerDefault() {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return open('$home/.decamp/server.db');
  }

  void _initialize() {
    _db.execute('PRAGMA foreign_keys = ON;');

    // Sessions table
    _db.execute('''
      CREATE TABLE IF NOT EXISTS sessions (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Messages table
    _db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        user_name TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        edited_at INTEGER,
        message_kind INTEGER NOT NULL DEFAULT 0,
        image_url TEXT,
        tool_calls_json TEXT,
        tool_results_json TEXT,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');

    // Indexes
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sessions_project ON sessions(project_id)',
    );
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sessions_updated ON sessions(project_id, updated_at DESC)',
    );
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_id)',
    );
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(session_id, created_at ASC)',
    );
  }

  /// Close the database
  void close() {
    _db.dispose();
  }

  // ============================================================
  // Sessions
  // ============================================================

  @override
  Future<List<Session>> getSessionsByProject(String projectId) async {
    final stmt = _db.prepare('''
      SELECT * FROM sessions WHERE project_id = ? ORDER BY updated_at DESC
    ''');
    try {
      return stmt.select([projectId]).map(_rowToSession).toList();
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<List<Session>> getNonArchivedSessionsByProject(
    String projectId,
  ) async {
    final stmt = _db.prepare('''
      SELECT * FROM sessions 
      WHERE project_id = ? AND is_archived = 0 
      ORDER BY updated_at DESC
    ''');
    try {
      return stmt.select([projectId]).map(_rowToSession).toList();
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<List<Session>> getArchivedSessionsByProject(String projectId) async {
    final stmt = _db.prepare('''
      SELECT * FROM sessions 
      WHERE project_id = ? AND is_archived = 1 
      ORDER BY updated_at DESC
    ''');
    try {
      return stmt.select([projectId]).map(_rowToSession).toList();
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<Session?> getSession(String sessionId) async {
    final stmt = _db.prepare('SELECT * FROM sessions WHERE id = ?');
    try {
      final results = stmt.select([sessionId]);
      return results.isEmpty ? null : _rowToSession(results.first);
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<void> createSession(Session session) async {
    final stmt = _db.prepare('''
      INSERT INTO sessions (id, project_id, description, created_at, updated_at, is_archived)
      VALUES (?, ?, ?, ?, ?, ?)
    ''');
    try {
      stmt.execute([
        session.id,
        session.projectId,
        session.description,
        session.createdAt.millisecondsSinceEpoch,
        session.updatedAt.millisecondsSinceEpoch,
        session.isArchived ? 1 : 0,
      ]);
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<void> updateSessionDescription(
    String sessionId,
    String description,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stmt = _db.prepare('''
      UPDATE sessions SET description = ?, updated_at = ? WHERE id = ?
    ''');
    try {
      stmt.execute([description, now, sessionId]);
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<void> setSessionArchived(String sessionId, bool archived) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stmt = _db.prepare('''
      UPDATE sessions SET is_archived = ?, updated_at = ? WHERE id = ?
    ''');
    try {
      stmt.execute([archived ? 1 : 0, now, sessionId]);
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<void> touchSession(String sessionId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stmt = _db.prepare('UPDATE sessions SET updated_at = ? WHERE id = ?');
    try {
      stmt.execute([now, sessionId]);
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final stmt = _db.prepare('DELETE FROM sessions WHERE id = ?');
    try {
      stmt.execute([sessionId]);
    } finally {
      stmt.dispose();
    }
  }

  // ============================================================
  // Messages
  // ============================================================

  @override
  Future<List<Message>> getMessagesBySession(String sessionId) async {
    final stmt = _db.prepare('''
      SELECT * FROM messages WHERE session_id = ? ORDER BY created_at ASC
    ''');
    try {
      return stmt.select([sessionId]).map(_rowToMessage).toList();
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<Message?> getMessage(String messageId) async {
    final stmt = _db.prepare('SELECT * FROM messages WHERE id = ?');
    try {
      final results = stmt.select([messageId]);
      return results.isEmpty ? null : _rowToMessage(results.first);
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<void> insertMessage(Message message) async {
    final stmt = _db.prepare('''
      INSERT OR REPLACE INTO messages 
      (id, session_id, user_id, user_name, content, created_at, edited_at,
       message_kind, image_url, tool_calls_json, tool_results_json)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    try {
      stmt.execute([
        message.id,
        message.sessionId,
        message.userId,
        message.userName,
        message.content,
        message.createdAt.millisecondsSinceEpoch,
        message.editedAt?.millisecondsSinceEpoch,
        message.messageKind.index,
        message.imageUrl,
        message.toolCallsJson,
        message.toolResultsJson,
      ]);
      // Touch the session
      await touchSession(message.sessionId);
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<void> updateMessageContent(String messageId, String content) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stmt = _db.prepare('''
      UPDATE messages SET content = ?, edited_at = ? WHERE id = ?
    ''');
    try {
      stmt.execute([content, now, messageId]);
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    final stmt = _db.prepare('DELETE FROM messages WHERE id = ?');
    try {
      stmt.execute([messageId]);
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<int> deleteMessagesAfter(
    String sessionId,
    DateTime afterTimestamp,
  ) async {
    // First count how many we'll delete
    final countStmt = _db.prepare('''
      SELECT COUNT(*) as count FROM messages 
      WHERE session_id = ? AND created_at > ?
    ''');
    int deleted;
    try {
      final results = countStmt.select([
        sessionId,
        afterTimestamp.millisecondsSinceEpoch,
      ]);
      deleted = results.first['count'] as int;
    } finally {
      countStmt.dispose();
    }

    // Now delete
    final deleteStmt = _db.prepare('''
      DELETE FROM messages WHERE session_id = ? AND created_at > ?
    ''');
    try {
      deleteStmt.execute([sessionId, afterTimestamp.millisecondsSinceEpoch]);
      await touchSession(sessionId);
    } finally {
      deleteStmt.dispose();
    }

    return deleted;
  }

  @override
  Future<int> getMessageCount(String sessionId) async {
    final stmt = _db.prepare(
      'SELECT COUNT(*) as count FROM messages WHERE session_id = ?',
    );
    try {
      final results = stmt.select([sessionId]);
      return results.first['count'] as int;
    } finally {
      stmt.dispose();
    }
  }

  // ============================================================
  // Row converters
  // ============================================================

  Session _rowToSession(Row row) {
    return Session(
      id: row['id'] as String,
      projectId: row['project_id'] as String,
      description: row['description'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      isArchived: (row['is_archived'] as int) == 1,
    );
  }

  Message _rowToMessage(Row row) {
    return Message(
      id: row['id'] as String,
      sessionId: row['session_id'] as String,
      userId: row['user_id'] as String,
      userName: row['user_name'] as String,
      content: row['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      editedAt: row['edited_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['edited_at'] as int)
          : null,
      messageKind: MessageKind.values[row['message_kind'] as int],
      imageUrl: row['image_url'] as String?,
      toolCallsJson: row['tool_calls_json'] as String?,
      toolResultsJson: row['tool_results_json'] as String?,
    );
  }
}
