import 'package:drift/drift.dart';
import '../converters/tool_call_converter.dart';

/// Message kind discriminator for sum type representation
enum MessageKind { text, imageUrl, toolUse, toolResult }

/// Messages table definition for Drift database.
/// Stores chat messages with foreign key to sessions.
/// Uses discriminated union pattern with messageKind to represent different message types.
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

  /// Timestamp when the message was last edited (null if never edited)
  DateTimeColumn get editedAt => dateTime().nullable()();

  /// Whether the message is deleted (soft delete for CRDT)
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// Whether the message is currently streaming
  BoolColumn get isStreaming => boolean().withDefault(const Constant(false))();

  /// Discriminator: what kind of message is this?
  IntColumn get messageKind =>
      intEnum<MessageKind>().withDefault(const Constant(0))();

  /// Image URL (only populated when messageKind = imageUrl)
  TextColumn get imageUrl => text().nullable()();

  // Discriminated union fields - only one of these sets should be populated
  // For MessageKind.toolUse
  TextColumn get toolCallsJson =>
      text().map(const ToolCallListConverter()).nullable()();

  // For MessageKind.toolResult
  TextColumn get toolResultsJson =>
      text().map(const ToolCallListConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        // Ensure only the appropriate column is populated for each message kind
        'CHECK ('
            '(message_kind = 0 AND image_url IS NULL AND tool_calls_json IS NULL AND tool_results_json IS NULL) OR ' // text
            '(message_kind = 1 AND image_url IS NOT NULL AND tool_calls_json IS NULL AND tool_results_json IS NULL) OR ' // imageUrl
            '(message_kind = 2 AND image_url IS NULL AND tool_calls_json IS NOT NULL AND tool_results_json IS NULL) OR ' // toolUse
            '(message_kind = 3 AND image_url IS NULL AND tool_calls_json IS NULL AND tool_results_json IS NOT NULL)' // toolResult
            ')',
      ];
}
