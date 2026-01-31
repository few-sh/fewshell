import 'package:drift/drift.dart';
import 'package:agent_core/agent_core.dart';

part 'message_subscriber_dao.g.dart';

/// Data Access Object for MessageSubscribers table.
/// Provides operations for managing push notification subscriptions.
@DriftAccessor(tables: [MessageSubscribers])
class MessageSubscriberDao extends DatabaseAccessor<ProjectDatabase>
    with _$MessageSubscriberDaoMixin {
  MessageSubscriberDao(super.db);

  /// Subscribe a device to a message
  Future<int> subscribe({
    required String messageId,
    required String sessionId,
    required String projectId,
    required String deviceToken,
    required DevicePlatform platform,
  }) async {
    final companion = MessageSubscriberEntityCompanion(
      messageId: Value(messageId),
      sessionId: Value(sessionId),
      projectId: Value(projectId),
      deviceToken: Value(deviceToken),
      platform: Value(platform),
      updatedAt: Value(DateTime.now()),
    );
    return await into(messageSubscribers)
        .insert(companion, mode: InsertMode.insertOrReplace);
  }

  /// Unsubscribe a device from a message
  Future<int> unsubscribe({
    required String messageId,
    required String deviceToken,
  }) async {
    // Perform soft delete by setting is_deleted = 1
    final result = await customUpdate(
      'UPDATE message_subscribers SET is_deleted = 1 WHERE message_id = ? AND device_token = ?',
      variables: [
        Variable.withString(messageId),
        Variable.withString(deviceToken),
      ],
      updates: {messageSubscribers},
    );
    return result;
  }

  /// Get all subscriptions for a specific message
  Stream<List<MessageSubscriberEntity>> watchSubscribersByMessage(
    String messageId,
  ) {
    return (select(messageSubscribers)
          ..where(
            (s) =>
                s.messageId.equals(messageId) &
                const CustomExpression<bool>('is_deleted').equals(false),
          ))
        .watch();
  }

  /// Get all subscriptions for a specific device token
  Stream<List<MessageSubscriberEntity>> watchSubscriptionsByDevice(
    String deviceToken,
  ) {
    return (select(messageSubscribers)
          ..where(
            (s) =>
                s.deviceToken.equals(deviceToken) &
                const CustomExpression<bool>('is_deleted').equals(false),
          ))
        .watch();
  }

  /// Get all subscriptions for a specific session and device
  Stream<List<MessageSubscriberEntity>> watchSubscriptionsBySessionAndDevice(
    String sessionId,
    String deviceToken,
  ) {
    return (select(messageSubscribers)
          ..where(
            (s) =>
                s.sessionId.equals(sessionId) &
                s.deviceToken.equals(deviceToken) &
                const CustomExpression<bool>('is_deleted').equals(false),
          ))
        .watch();
  }

  /// Delete all subscriptions for a message (cleanup)
  Future<int> deleteSubscriptionsByMessage(String messageId) async {
    final result = await customUpdate(
      'UPDATE message_subscribers SET is_deleted = 1 WHERE message_id = ?',
      variables: [Variable.withString(messageId)],
      updates: {messageSubscribers},
    );
    return result;
  }

  /// Delete all subscriptions for a session (cleanup)
  Future<int> deleteSubscriptionsBySession(String sessionId) async {
    final result = await customUpdate(
      'UPDATE message_subscribers SET is_deleted = 1 WHERE session_id = ?',
      variables: [Variable.withString(sessionId)],
      updates: {messageSubscribers},
    );
    return result;
  }

  /// Cleanup all subscriptions (soft delete)
  /// Returns the number of subscriptions cleaned up.
  /// Use with caution.
  Future<int> cleanupAll() {
    return delete(messageSubscribers).go();
  }
}
