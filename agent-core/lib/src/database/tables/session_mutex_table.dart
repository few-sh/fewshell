import 'package:drift/drift.dart';

/// Session Mutex table definition for Drift database.
/// Used to handle locking for sessions.
@DataClassName('SessionMutexEntity')
class SessionMutexes extends Table {
  /// Unique identifier for the session (or mutex key)
  TextColumn get id => text()();

  /// Timestamp when the lock was acquired or refreshed
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
