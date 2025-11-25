import 'package:drift/drift.dart';

/// Projects table definition for Drift database.
/// Stores project information including metadata and timestamps.
@DataClassName('ProjectEntity')
class Projects extends Table {
  /// Unique identifier for the project
  TextColumn get id => text()();

  /// Project name
  TextColumn get name => text().withLength(min: 1, max: 255)();

  /// Optional project description
  TextColumn get description => text().nullable()();

  /// Server URL for remote execution.
  /// null = local project (runs on device)
  /// URL = remote project (runs on server via WebSocket)
  TextColumn get serverUrl => text().nullable()();

  /// Timestamp of the last session activity
  DateTimeColumn get lastSessionDate => dateTime()();

  /// Timestamp when the project was created
  DateTimeColumn get createdAt => dateTime()();

  /// Timestamp when the project was last updated
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
