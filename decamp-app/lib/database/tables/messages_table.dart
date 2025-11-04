import 'package:drift/drift.dart';

/// Messages table definition for Drift database.
/// Stores chat messages with foreign key to sessions.
@DataClassName('MessageEntity')
class Messages extends Table {
  /// Unique identifier for the message
  TextColumn get id => text()();

  /// Foreign key to the session this message belongs to
  TextColumn get sessionId => text()();

  /// User ID (e.g., 'user' or 'ai')
  TextColumn get userId => text()();

  /// User name for display
  TextColumn get userName => text()();

  /// Message content/text
  TextColumn get content => text()();

  /// Timestamp when the message was sent
  DateTimeColumn get timestamp => dateTime()();

  /// Timestamp when the message was created
  DateTimeColumn get createdAt => dateTime()();

  /// Optional image URL
  TextColumn get imageUrl => text().nullable()();

  /// Optional metadata as JSON string
  TextColumn get metadata => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
