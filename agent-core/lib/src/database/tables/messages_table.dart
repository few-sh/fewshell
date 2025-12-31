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

  /// Whether the message is currently streaming
  BoolColumn get isStreaming => boolean().withDefault(const Constant(false))();

  /// Whether the message should be visible to the LLM (included in conversation history)
  BoolColumn get isVisibleToLlm =>
      boolean().withDefault(const Constant(true))();

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
        // WARNING: DO NOT ADD CONSTRAINTS, as they may cause issues with CRDT merges
      ];
}
