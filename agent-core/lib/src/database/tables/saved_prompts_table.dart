import 'package:drift/drift.dart';
import '../entities/saved_prompt_entity.dart';

/// SavedPrompts table definition for Drift database.
/// Stores reusable prompts.
@UseRowClass(SavedPromptEntity)
class SavedPrompts extends Table {
  /// Unique identifier for the saved prompt
  TextColumn get id => text()();

  /// Optional foreign key to project (null for global saved prompts)
  TextColumn get projectId => text().nullable()();

  /// Prompt content
  TextColumn get content => text()();

  /// Optional description
  TextColumn get description => text().nullable()();

  /// Tags as comma-separated string
  TextColumn get tags => text().withDefault(const Constant(''))();

  /// Timestamp when the saved prompt was created
  DateTimeColumn get createdAt => dateTime()();

  /// Timestamp when the saved prompt was last updated
  DateTimeColumn get updatedAt => dateTime()();

  /// Timestamp when the saved prompt was last used
  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
