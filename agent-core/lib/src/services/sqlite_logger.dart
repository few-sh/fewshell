import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:sqlite3/sqlite3.dart';

/// A logger sink that writes logs to a SQLite database.
///
/// This implementation uses low-level sqlite3 bindings and does not depend on
/// drift or other ORMs.
class SqliteLogger {
  final String dbPath;
  final String tableName;
  final String appVersion;
  final String processId;
  late final Database _db;
  bool _initialized = false;

  SqliteLogger({
    required this.dbPath,
    required this.tableName,
    required this.appVersion,
    required this.processId,
  }) {
    _init();
  }

  void _init() {
    try {
      // Ensure directory exists
      final dir = File(dbPath).parent;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      _db = sqlite3.open(dbPath);
      _createTable();
      _initialized = true;

      // Subscribe to the root logger
      Logger.root.onRecord.listen(log);
    } catch (e) {
      // ignore: avoid_print
      print('Failed to initialize SqliteLogger: $e');
    }
  }

  void _createTable() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        time INTEGER NOT NULL,
        pretty_time TEXT GENERATED ALWAYS AS (datetime(time / 1000000, 'unixepoch')) VIRTUAL,
        level INTEGER NOT NULL,
        level_name TEXT NOT NULL,
        message TEXT NOT NULL,
        logger_name TEXT NOT NULL,
        error TEXT,
        stack_trace TEXT,
        object TEXT,
        app_version TEXT,
        process_id TEXT
      )
    ''');
  }

  /// Writes a log record to the database.
  void log(LogRecord record) {
    if (!_initialized) return;

    try {
      final stmt = _db.prepare('''
        INSERT INTO $tableName (
          time, level, level_name, message, logger_name, error, stack_trace, object, app_version, process_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');

      String? objectJson;
      if (record.object != null) {
        try {
          objectJson = jsonEncode(record.object);
        } catch (e) {
          // Fallback to toString if not json encodable
          objectJson = record.object.toString();
        }
      }

      stmt.execute([
        record.time.microsecondsSinceEpoch,
        record.level.value,
        record.level.name,
        record.message,
        record.loggerName,
        record.error?.toString(),
        record.stackTrace?.toString(),
        objectJson,
        appVersion,
        processId,
      ]);
      stmt.dispose();
    } catch (e) {
      // Avoid infinite recursion if logging fails, just print to stderr
      // ignore: avoid_print
      print('Failed to write to SqliteLogger: $e');
    }
  }

  /// Closes the database connection.
  void dispose() {
    if (_initialized) {
      _db.dispose();
      _initialized = false;
    }
  }
}
