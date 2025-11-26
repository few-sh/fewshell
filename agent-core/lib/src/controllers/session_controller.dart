import 'dart:async';

import '../models/message.dart';
import '../models/session.dart';
import '../types.dart';

// Re-export types for consumers
export '../types.dart'
    show
        AgentLoopResult,
        AgentLoopCompleted,
        AgentLoopCancelled,
        AgentLoopError,
        PendingToolCall;

/// Unified controller interface for session management.
///
/// This is the Quake-style abstraction: same interface whether you're
/// running locally (single-player) or remotely (multiplayer).
///
/// The UI talks to this interface only. It doesn't know or care whether
/// the implementation is:
/// - LocalSessionController: Direct agent-core calls with local SQLite
/// - RemoteSessionController: WebSocket to decamp-agent server
///
/// Key insight: Real-time updates work the same way in both cases:
/// - Local: Controller fires stream after each write
/// - Remote: Controller fires stream when server pushes updates
abstract class SessionController {
  /// The project ID this controller is bound to
  String get projectId;

  /// Whether currently connected/ready
  bool get isConnected;

  // ============================================================
  // Connection Lifecycle
  // ============================================================

  /// Connect to the data source (no-op for local, WebSocket for remote)
  Future<bool> connect();

  /// Disconnect and clean up resources
  Future<void> disconnect();

  /// Dispose all resources (call when done with this controller)
  void dispose();

  // ============================================================
  // Sessions - Reactive Streams
  // ============================================================

  /// Watch all sessions for the project, ordered by updatedAt desc
  Stream<List<Session>> watchSessions();

  /// Watch non-archived sessions
  Stream<List<Session>> watchActiveSessions();

  /// Watch archived sessions
  Stream<List<Session>> watchArchivedSessions();

  // ============================================================
  // Sessions - CRUD
  // ============================================================

  /// Get a single session by ID
  Future<Session?> getSession(String sessionId);

  /// Create a new session, returns the created session
  Future<Session> createSession({String? description});

  /// Update session description
  Future<void> updateSessionDescription(String sessionId, String description);

  /// Archive/unarchive a session
  Future<void> setSessionArchived(String sessionId, bool archived);

  /// Delete a session and all its messages
  Future<void> deleteSession(String sessionId);

  // ============================================================
  // Messages - Reactive Streams
  // ============================================================

  /// Watch all messages for a session, ordered by createdAt asc
  Stream<List<Message>> watchMessages(String sessionId);

  // ============================================================
  // Messages - CRUD
  // ============================================================

  /// Get all messages for a session
  Future<List<Message>> getMessages(String sessionId);

  /// Get message count for a session
  Future<int> getMessageCount(String sessionId);

  /// Get a single message by ID
  Future<Message?> getMessage(String messageId);

  /// Update a message's content (for editing)
  Future<void> updateMessageContent(String messageId, String newContent);

  /// Delete all messages after a given timestamp in a session
  /// Returns the number of deleted messages
  Future<int> deleteMessagesAfter(String sessionId, DateTime afterTimestamp);

  // ============================================================
  // Agent Loop Execution
  // ============================================================

  /// Send a message and run the agent loop.
  ///
  /// This is the core operation: user sends a message, agent responds.
  ///
  /// Parameters:
  /// - [sessionId]: Session to run in
  /// - [content]: User's message content
  /// - [onTextDelta]: Called with each text chunk as it streams
  /// - [onMessage]: Called when a complete message is ready (user, assistant, or tool)
  /// - [requestApproval]: Called when tools need approval, return indices to approve or null to cancel
  ///
  /// Returns the result of the agent loop (completed, cancelled, or error).
  Future<AgentLoopResult> sendMessage({
    required String sessionId,
    required String content,
    required void Function(String delta) onTextDelta,
    required void Function(Message message) onMessage,
    required Future<List<int>?> Function(List<PendingToolCall> tools)
        requestApproval,
  });

  /// Continue the conversation without adding a user message.
  ///
  /// Used for resend/edit operations where the conversation has been modified
  /// and we want to re-run the agent loop from the current state.
  ///
  /// Parameters are the same as [sendMessage] except no content is provided.
  Future<AgentLoopResult> continueConversation({
    required String sessionId,
    required void Function(String delta) onTextDelta,
    required void Function(Message message) onMessage,
    required Future<List<int>?> Function(List<PendingToolCall> tools)
        requestApproval,
  });

  /// Approve pending tool calls (indices of tools to approve)
  void approvePendingTools(List<int> indices);

  /// Cancel the current operation
  void cancel();
}
