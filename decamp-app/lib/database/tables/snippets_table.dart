import 'package:drift/drift.dart';

/// Snippets table definition for Drift database.
/// Stores reusable code/command snippets.
@DataClassName('SnippetEntity')
class Snippets extends Table {
  /// Unique identifier for the snippet
  TextColumn get id => text()();

  /// Optional foreign key to project (null for global snippets)
  TextColumn get projectId => text().nullable()();

  /// Snippet name
  TextColumn get name => text().withLength(min: 1, max: 255)();

  /// Snippet content (code or command)
  TextColumn get content => text()();

  /// Optional description
  TextColumn get description => text().nullable()();

  /// Tags as comma-separated string
  TextColumn get tags => text().withDefault(const Constant(''))();

  /// Timestamp when the snippet was created
  DateTimeColumn get createdAt => dateTime()();

  /// Timestamp when the snippet was last updated
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
