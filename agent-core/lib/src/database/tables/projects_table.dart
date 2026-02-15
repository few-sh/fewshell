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

  /// Optional server URL for CRDT sync
  /// If null, the project is local-only
  TextColumn get serverUrl => text().nullable()();

  /// Server's CRDT node ID (e.g. `srv_<uuid>`)
  /// Set by the server, replicated to all clients via CRDT.
  /// Used for sync filtering and server identity.
  /// If null, the project has not yet been assigned to a server.
  ///
  /// Named `serverNodeId` (not `nodeId`) to avoid colliding with the CRDT
  /// metadata column `node_id` that SqliteCrdt adds to every table.
  TextColumn get serverNodeId => text().nullable()();

  /// Timestamp of the last session activity
  DateTimeColumn get lastSessionDate => dateTime()();

  /// Timestamp when the project was created
  DateTimeColumn get createdAt => dateTime()();

  /// Timestamp when the project was last updated
  DateTimeColumn get updatedAt => dateTime()();

  /// Whether the project is archived
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
