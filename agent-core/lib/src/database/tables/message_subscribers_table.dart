import 'package:drift/drift.dart';

/// Device platform discriminator for push notifications
enum DevicePlatform { ios, android }

/// MessageSubscribers table definition for Drift database.
/// Stores device subscriptions to messages for push notifications.
@DataClassName('MessageSubscriberEntity')
class MessageSubscribers extends Table {
  /// Foreign key to the message this subscription is for
  TextColumn get messageId => text()();

  /// Foreign key to the session (for reference)
  TextColumn get sessionId => text()();

  /// Foreign key to the project (for reference)
  TextColumn get projectId => text()();

  /// Device token for push notifications
  TextColumn get deviceToken => text()();

  /// Platform type (iOS or Android)
  IntColumn get platform => intEnum<DevicePlatform>()();

  /// Timestamp when the subscription was last updated
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {messageId, deviceToken};

  @override
  List<String> get customConstraints => [
        // WARNING: DO NOT ADD CONSTRAINTS, as they may cause issues with CRDT merges
      ];
}
