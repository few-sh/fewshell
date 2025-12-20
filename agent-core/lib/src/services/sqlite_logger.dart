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

  /// Creates a temporary copy of the log database.
  /// Returns a [File] pointing to the temporary copy.
  /// The caller is responsible for deleting the file (and its parent directory) when done.
  Future<File> createLogSnapshot() async {
    if (!_initialized) {
      throw StateError('Logger not initialized');
    }

    // Flush the database to ensure all data is written to disk
    try {
      _db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    } catch (e) {
      // Ignore errors during checkpoint (e.g. if not in WAL mode)
    }

    // Create a temporary directory for the snapshot
    final tempDir = Directory.systemTemp.createTempSync('decamp_logs_');
    final tempPath = '${tempDir.path}/logs.db';

    // Copy the database file
    await File(dbPath).copy(tempPath);

    return File(tempPath);
  }

  /// Closes the database connection.
  void dispose() {
    if (_initialized) {
      _db.dispose();
      _initialized = false;
    }
  }
}
