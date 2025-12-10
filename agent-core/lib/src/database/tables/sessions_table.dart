import 'package:drift/drift.dart';

/// Sessions table definition for Drift database.
/// Stores chat session information with foreign key to projects.
@DataClassName('SessionEntity')
class Sessions extends Table {
  /// Unique identifier for the session
  TextColumn get id => text()();

  /// Foreign key to the project this session belongs to
  TextColumn get projectId => text()();

  /// Description or title of the session
  TextColumn get description => text().withLength(min: 1, max: 500)();

  /// Timestamp when the session was created/started
  DateTimeColumn get timestamp => dateTime()();

  /// Timestamp when the session was created
  DateTimeColumn get createdAt => dateTime()();

  /// Timestamp when the session was last updated
  DateTimeColumn get updatedAt => dateTime()();

  /// Whether the session is archived
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// Whether the session is starred
  BoolColumn get isStarred => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
