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

  /// Threshold in bytes at which to trigger truncation (default: 15 MB)
  final int truncationThreshold;

  /// Target size in bytes after truncation (default: 10 MB)
  final int targetSize;

  late final Database _db;
  bool _initialized = false;

  SqliteLogger({
    required this.dbPath,
    required this.tableName,
    required this.appVersion,
    required this.processId,
    this.truncationThreshold = 4 * 1024 * 1024, // 4 MB
    this.targetSize = 2 * 1024 * 1024, // 2 MB
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

      // Check and truncate logs if needed during initialization
      _truncateIfNeeded();

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

  /// Calculates the approximate size of log records in bytes.
  /// Estimates size by summing the lengths of string columns.
  int _calculateRecordsSize() {
    try {
      final result = _db.select('''
        SELECT COALESCE(SUM(
          LENGTH(COALESCE(message, '')) +
          LENGTH(COALESCE(logger_name, '')) +
          LENGTH(COALESCE(error, '')) +
          LENGTH(COALESCE(stack_trace, '')) +
          LENGTH(COALESCE(object, ''))
        ), 0) as total_size
        FROM $tableName
      ''');

      if (result.isNotEmpty) {
        return result.first['total_size'] as int;
      }
      return 0;
    } catch (e) {
      // ignore: avoid_print
      print('Failed to calculate log records size: $e');
      return 0;
    }
  }

  /// Truncates old log records to keep the database under the target size.
  /// Returns the number of records deleted and the size reclaimed (in bytes).
  /// Logs a message after truncation completes.
  Future<({int recordsDeleted, int bytesReclaimed})> truncateLogs() async {
    if (!_initialized) {
      throw StateError('Logger not initialized');
    }

    try {
      final currentSize = _calculateRecordsSize();

      // If we're under the target, no need to truncate
      if (currentSize <= targetSize) {
        return (recordsDeleted: 0, bytesReclaimed: 0);
      }

      int sizeToRemove = currentSize - targetSize;
      int bytesReclaimed = 0;
      int maxIdToDelete = 0;

      // Find the oldest records to delete in a single query
      final recordsToDelete = _db.select('''
        SELECT id,
          LENGTH(COALESCE(message, '')) +
          LENGTH(COALESCE(logger_name, '')) +
          LENGTH(COALESCE(error, '')) +
          LENGTH(COALESCE(stack_trace, '')) +
          LENGTH(COALESCE(object, '')) as record_size
        FROM $tableName
        ORDER BY id ASC
      ''');

      for (final record in recordsToDelete) {
        if (bytesReclaimed >= sizeToRemove) break;

        final recordId = record['id'] as int;
        final recordSize = record['record_size'] as int;

        maxIdToDelete = recordId;
        bytesReclaimed += recordSize;
      }

      // Count records to be deleted before deleting them
      int recordsDeleted = 0;
      if (maxIdToDelete > 0) {
        final countResult = _db.select(
            'SELECT COUNT(*) as count FROM $tableName WHERE id <= ?',
            [maxIdToDelete]);
        if (countResult.isNotEmpty) {
          recordsDeleted = countResult.first['count'] as int;
        }

        // Delete all records up to maxIdToDelete in a single operation
        _db.execute('DELETE FROM $tableName WHERE id <= ?', [maxIdToDelete]);

        // Rebuild the database file to reclaim unused disk space
        _db.execute('VACUUM');
      }

      // Log the truncation event
      Logger.root.info(
        'SqliteLogger: Truncated database. '
        'Deleted $recordsDeleted records, reclaimed ${(bytesReclaimed / 1024 / 1024).toStringAsFixed(2)} MB. '
        'New size: ${((currentSize - bytesReclaimed) / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      return (recordsDeleted: recordsDeleted, bytesReclaimed: bytesReclaimed);
    } catch (e) {
      // ignore: avoid_print
      print('Failed to truncate logs: $e');
      rethrow;
    }
  }

  /// Checks if truncation is needed and performs it if necessary.
  void _truncateIfNeeded() {
    try {
      final currentSize = _calculateRecordsSize();
      if (currentSize > truncationThreshold) {
        truncateLogs();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error during automatic log truncation: $e');
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
