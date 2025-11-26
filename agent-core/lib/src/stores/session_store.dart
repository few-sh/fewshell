import '../models/message.dart';
import '../models/session.dart';

/// Abstract interface for session and message storage.
///
/// Implementations:
/// - Server: SQLite database
/// - Client: Could wrap Drift database or use this interface directly
///
/// The server is the source of truth for remote projects.
/// The client is the source of truth for local projects.
abstract class SessionStore {
  // ============================================================
  // Sessions
  // ============================================================

  /// Get all sessions for a project, ordered by updatedAt descending
  Future<List<Session>> getSessionsByProject(String projectId);

  /// Get non-archived sessions for a project
  Future<List<Session>> getNonArchivedSessionsByProject(String projectId);

  /// Get archived sessions for a project
  Future<List<Session>> getArchivedSessionsByProject(String projectId);

  /// Get a session by ID
  Future<Session?> getSession(String sessionId);

  /// Create a new session
  Future<void> createSession(Session session);

  /// Update session description
  Future<void> updateSessionDescription(String sessionId, String description);

  /// Update session archived state
  Future<void> setSessionArchived(String sessionId, bool archived);

  /// Touch session (update updatedAt timestamp)
  Future<void> touchSession(String sessionId);

  /// Delete a session and all its messages
  Future<void> deleteSession(String sessionId);

  // ============================================================
  // Messages
  // ============================================================

  /// Get all messages for a session, ordered by createdAt ascending
  Future<List<Message>> getMessagesBySession(String sessionId);

  /// Get a message by ID
  Future<Message?> getMessage(String messageId);

  /// Insert a message
  Future<void> insertMessage(Message message);

  /// Update message content and set editedAt
  Future<void> updateMessageContent(String messageId, String content);

  /// Delete a message
  Future<void> deleteMessage(String messageId);

  /// Delete all messages after a timestamp in a session.
  /// Returns the number of deleted messages.
  Future<int> deleteMessagesAfter(String sessionId, DateTime afterTimestamp);

  /// Get message count for a session
  Future<int> getMessageCount(String sessionId);
}
