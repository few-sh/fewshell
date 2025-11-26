import 'dart:async';
import 'dart:convert';

import 'package:llm_dart/llm_dart.dart';

import '../agent_loop.dart';
import '../message_converter.dart';
import '../models/message.dart';
import '../models/session.dart';
import '../stores/session_store.dart';
import '../tools.dart';
import '../types.dart';
import '../utils/id_generator.dart';
import 'session_controller.dart';

/// Local implementation of SessionController.
///
/// This is the "single-player" mode: runs agent loop directly in-process,
/// stores data in local SQLite database.
///
/// Key insight: We don't need Drift's watch() - we just fire our own
/// StreamControllers when we write data. Same result, simpler code.
class LocalSessionController implements SessionController {
  @override
  final String projectId;

  final SessionStore _store;
  final Future<ChatCapability?> Function() _createLlmClient;
  final ToolExecutionFunction _executeToolCall;

  // Stream controllers for reactive updates
  final _sessionControllers = <String, StreamController<List<Session>>>{};
  final _messageControllers = <String, StreamController<List<Message>>>{};

  // Agent loop state
  Completer<List<PendingToolCall>?>? _approvalCompleter;
  bool _isCancelled = false;

  LocalSessionController({
    required this.projectId,
    required SessionStore store,
    required Future<ChatCapability?> Function() createLlmClient,
    required ToolExecutionFunction executeToolCall,
  })  : _store = store,
        _createLlmClient = createLlmClient,
        _executeToolCall = executeToolCall;

  @override
  bool get isConnected => true; // Local is always "connected"

  @override
  Future<bool> connect() async => true; // No-op for local

  @override
  Future<void> disconnect() async {} // No-op for local

  @override
  void dispose() {
    for (final controller in _sessionControllers.values) {
      controller.close();
    }
    for (final controller in _messageControllers.values) {
      controller.close();
    }
    _sessionControllers.clear();
    _messageControllers.clear();
  }

  // ============================================================
  // Sessions - Reactive Streams
  // ============================================================

  @override
  Stream<List<Session>> watchSessions() {
    return _getOrCreateSessionStream(
        'all', () => _store.getSessionsByProject(projectId));
  }

  @override
  Stream<List<Session>> watchActiveSessions() {
    return _getOrCreateSessionStream(
      'active',
      () => _store.getNonArchivedSessionsByProject(projectId),
    );
  }

  @override
  Stream<List<Session>> watchArchivedSessions() {
    return _getOrCreateSessionStream(
      'archived',
      () => _store.getArchivedSessionsByProject(projectId),
    );
  }

  Stream<List<Session>> _getOrCreateSessionStream(
    String key,
    Future<List<Session>> Function() fetcher,
  ) {
    final fullKey = '$projectId:$key';
    if (!_sessionControllers.containsKey(fullKey)) {
      final controller = StreamController<List<Session>>.broadcast(
        onListen: () async {
          final sessions = await fetcher();
          _sessionControllers[fullKey]?.add(sessions);
        },
      );
      _sessionControllers[fullKey] = controller;
    }
    return _sessionControllers[fullKey]!.stream;
  }

  /// Notify all session streams to refresh
  Future<void> _notifySessionsChanged() async {
    // Refresh each stream type
    for (final entry in _sessionControllers.entries) {
      final key = entry.key;
      final controller = entry.value;

      if (key.endsWith(':all')) {
        final sessions = await _store.getSessionsByProject(projectId);
        controller.add(sessions);
      } else if (key.endsWith(':active')) {
        final sessions =
            await _store.getNonArchivedSessionsByProject(projectId);
        controller.add(sessions);
      } else if (key.endsWith(':archived')) {
        final sessions = await _store.getArchivedSessionsByProject(projectId);
        controller.add(sessions);
      }
    }
  }

  // ============================================================
  // Sessions - CRUD
  // ============================================================

  @override
  Future<Session?> getSession(String sessionId) => _store.getSession(sessionId);

  @override
  Future<Session> createSession({String? description}) async {
    final now = DateTime.now();
    final session = Session(
      id: IdGenerator.sessionId(),
      projectId: projectId,
      description: description ?? '',
      createdAt: now,
      updatedAt: now,
      isArchived: false,
    );
    await _store.createSession(session);
    await _notifySessionsChanged();
    return session;
  }

  @override
  Future<void> updateSessionDescription(
    String sessionId,
    String description,
  ) async {
    await _store.updateSessionDescription(sessionId, description);
    await _notifySessionsChanged();
  }

  @override
  Future<void> setSessionArchived(String sessionId, bool archived) async {
    await _store.setSessionArchived(sessionId, archived);
    await _notifySessionsChanged();
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await _store.deleteSession(sessionId);
    await _notifySessionsChanged();
    // Also notify the message stream for this session
    _messageControllers[sessionId]?.add([]);
  }

  // ============================================================
  // Messages - Reactive Streams
  // ============================================================

  @override
  Stream<List<Message>> watchMessages(String sessionId) {
    if (!_messageControllers.containsKey(sessionId)) {
      final controller = StreamController<List<Message>>.broadcast(
        onListen: () async {
          final messages = await _store.getMessagesBySession(sessionId);
          _messageControllers[sessionId]?.add(messages);
        },
      );
      _messageControllers[sessionId] = controller;
    }
    return _messageControllers[sessionId]!.stream;
  }

  Future<void> _notifyMessagesChanged(String sessionId) async {
    final controller = _messageControllers[sessionId];
    if (controller != null) {
      final messages = await _store.getMessagesBySession(sessionId);
      controller.add(messages);
    }
  }

  // ============================================================
  // Messages - CRUD
  // ============================================================

  @override
  Future<List<Message>> getMessages(String sessionId) =>
      _store.getMessagesBySession(sessionId);

  @override
  Future<int> getMessageCount(String sessionId) =>
      _store.getMessageCount(sessionId);

  @override
  Future<Message?> getMessage(String messageId) => _store.getMessage(messageId);

  @override
  Future<void> updateMessageContent(String messageId, String newContent) async {
    await _store.updateMessageContent(messageId, newContent);
    // Note: We don't have the sessionId here, so we can't notify.
    // The caller should handle refreshing as needed.
  }

  @override
  Future<int> deleteMessagesAfter(
    String sessionId,
    DateTime afterTimestamp,
  ) async {
    final deleted = await _store.deleteMessagesAfter(sessionId, afterTimestamp);
    await _notifyMessagesChanged(sessionId);
    return deleted;
  }

  // ============================================================
  // Agent Loop Execution
  // ============================================================

  @override
  Future<AgentLoopResult> sendMessage({
    required String sessionId,
    required String content,
    required void Function(String delta) onTextDelta,
    required void Function(Message message) onMessage,
    required Future<List<int>?> Function(List<PendingToolCall> tools)
        requestApproval,
  }) async {
    _isCancelled = false;

    // Get or create session
    var session = await _store.getSession(sessionId);
    if (session == null) {
      session = await createSession(description: _truncate(content, 100));
    }

    // Load existing conversation
    final dbMessages = await _store.getMessagesBySession(sessionId);
    final conversation = <ChatMessage>[];
    for (final msg in dbMessages) {
      try {
        conversation.add(_messageToChat(msg));
      } catch (e) {
        // Skip invalid messages
      }
    }

    // Create and persist user message
    final userMessage = _createMessage(
      sessionId: sessionId,
      userId: kUserUserId,
      userName: kUserUserName,
      content: content,
      kind: MessageKind.text,
    );
    await _store.insertMessage(userMessage);
    conversation.add(ChatMessage.user(content));
    onMessage(userMessage);
    await _notifyMessagesChanged(sessionId);

    // Update session description if first message
    if (dbMessages.isEmpty) {
      await _store.updateSessionDescription(sessionId, _truncate(content, 100));
      await _notifySessionsChanged();
    }

    // Get LLM client
    final llm = await _createLlmClient();
    if (llm == null) {
      return AgentLoopError('LLM not configured');
    }

    // Run the agent loop
    final result = await runAgentLoop(
      llmStream: (conv, tools) => llm.chatStream(conv, tools: tools),
      tools: shellTools,
      conversation: conversation,
      requestApproval: (pendingCalls) async {
        if (_isCancelled) return null;

        // Ask UI which indices to approve
        final approvedIndices = await requestApproval(pendingCalls);
        if (approvedIndices == null) return null;

        // Convert indices back to PendingToolCalls
        return approvedIndices
            .where((i) => i >= 0 && i < pendingCalls.length)
            .map((i) => pendingCalls[i])
            .toList();
      },
      executeToolCall: _executeToolCall,
      onTextDelta: onTextDelta,
      onAssistantMessage: (chatMsg) async {
        final message = _chatToMessage(chatMsg, sessionId: sessionId);
        await _store.insertMessage(message);
        onMessage(message);
        await _notifyMessagesChanged(sessionId);
      },
      onToolResultMessage: (chatMsg) async {
        final message = _chatToMessage(chatMsg, sessionId: sessionId);
        await _store.insertMessage(message);
        onMessage(message);
        await _notifyMessagesChanged(sessionId);
      },
    );

    // The result is already the right type
    return result;
  }

  @override
  Future<AgentLoopResult> continueConversation({
    required String sessionId,
    required void Function(String delta) onTextDelta,
    required void Function(Message message) onMessage,
    required Future<List<int>?> Function(List<PendingToolCall> tools)
        requestApproval,
  }) async {
    _isCancelled = false;

    // Session must exist
    final session = await _store.getSession(sessionId);
    if (session == null) {
      return AgentLoopError('Session not found');
    }

    // Load existing conversation
    final dbMessages = await _store.getMessagesBySession(sessionId);
    final conversation = <ChatMessage>[];
    for (final msg in dbMessages) {
      try {
        conversation.add(_messageToChat(msg));
      } catch (e) {
        // Skip invalid messages
      }
    }

    if (conversation.isEmpty) {
      return AgentLoopError('No messages in conversation');
    }

    // Get LLM client
    final llm = await _createLlmClient();
    if (llm == null) {
      return AgentLoopError('LLM not configured');
    }

    // Run the agent loop (same as sendMessage, but no user message added)
    return await runAgentLoop(
      llmStream: (conv, tools) => llm.chatStream(conv, tools: tools),
      tools: shellTools,
      conversation: conversation,
      requestApproval: (pendingCalls) async {
        if (_isCancelled) return null;

        final approvedIndices = await requestApproval(pendingCalls);
        if (approvedIndices == null) return null;

        return approvedIndices
            .where((i) => i >= 0 && i < pendingCalls.length)
            .map((i) => pendingCalls[i])
            .toList();
      },
      executeToolCall: _executeToolCall,
      onTextDelta: onTextDelta,
      onAssistantMessage: (chatMsg) async {
        final message = _chatToMessage(chatMsg, sessionId: sessionId);
        await _store.insertMessage(message);
        onMessage(message);
        await _notifyMessagesChanged(sessionId);
      },
      onToolResultMessage: (chatMsg) async {
        final message = _chatToMessage(chatMsg, sessionId: sessionId);
        await _store.insertMessage(message);
        onMessage(message);
        await _notifyMessagesChanged(sessionId);
      },
    );
  }

  @override
  void approvePendingTools(List<int> indices) {
    // This method isn't used by LocalSessionController since approval
    // is handled synchronously via the requestApproval callback.
    // It's here for interface compliance with RemoteSessionController.
  }

  @override
  void cancel() {
    _isCancelled = true;
    _approvalCompleter?.complete(null);
    _approvalCompleter = null;
  }

  // ============================================================
  // Message Conversion Helpers
  // ============================================================

  Message _createMessage({
    required String sessionId,
    required String userId,
    required String userName,
    required String content,
    required MessageKind kind,
    String? imageUrl,
    String? toolCallsJson,
    String? toolResultsJson,
  }) {
    return Message(
      id: IdGenerator.messageId(),
      sessionId: sessionId,
      userId: userId,
      userName: userName,
      content: content,
      createdAt: DateTime.now(),
      messageKind: kind,
      imageUrl: imageUrl,
      toolCallsJson: toolCallsJson,
      toolResultsJson: toolResultsJson,
    );
  }

  Message _chatToMessage(ChatMessage chatMsg, {required String sessionId}) {
    final MessageKind kind;
    String? imageUrl;
    String? toolCallsJson;
    String? toolResultsJson;

    switch (chatMsg.messageType) {
      case TextMessage():
        kind = MessageKind.text;

      case ImageUrlMessage(:final url):
        kind = MessageKind.imageUrl;
        imageUrl = url;

      case ToolUseMessage(:final toolCalls):
        kind = MessageKind.toolUse;
        toolCallsJson = jsonEncode(toolCalls.map(toolCallToMap).toList());

      case ToolResultMessage(:final results):
        kind = MessageKind.toolResult;
        toolResultsJson = jsonEncode(results.map(toolCallToMap).toList());

      default:
        kind = MessageKind.text;
    }

    return _createMessage(
      sessionId: sessionId,
      userId: _userIdFromRole(chatMsg.role),
      userName: _userNameFromRole(chatMsg.role),
      content: chatMsg.content,
      kind: kind,
      imageUrl: imageUrl,
      toolCallsJson: toolCallsJson,
      toolResultsJson: toolResultsJson,
    );
  }

  ChatMessage _messageToChat(Message msg) {
    final role = _roleFromUserId(msg.userId);

    switch (msg.messageKind) {
      case MessageKind.text:
        return role == ChatRole.user
            ? ChatMessage.user(msg.content)
            : ChatMessage.assistant(msg.content);

      case MessageKind.imageUrl:
        return ChatMessage.imageUrl(
          role: role,
          url: msg.imageUrl ?? '',
          content: msg.content,
        );

      case MessageKind.toolUse:
        final toolCalls = msg.toolCallsJson != null
            ? _parseToolCalls(msg.toolCallsJson!)
            : <ToolCall>[];
        return ChatMessage.toolUse(toolCalls: toolCalls, content: msg.content);

      case MessageKind.toolResult:
        final results = msg.toolResultsJson != null
            ? _parseToolCalls(msg.toolResultsJson!)
            : <ToolCall>[];
        return ChatMessage.toolResult(results: results, content: msg.content);
    }
  }

  String _userIdFromRole(ChatRole role) => switch (role) {
        ChatRole.user => kUserUserId,
        ChatRole.assistant => kAiUserId,
        ChatRole.system => kSystemUserId,
      };

  String _userNameFromRole(ChatRole role) => switch (role) {
        ChatRole.user => kUserUserName,
        ChatRole.assistant => kAiUserName,
        ChatRole.system => kSystemUserName,
      };

  ChatRole _roleFromUserId(String userId) => switch (userId) {
        kUserUserId => ChatRole.user,
        kAiUserId => ChatRole.assistant,
        kSystemUserId => ChatRole.system,
        _ => ChatRole.assistant,
      };

  List<ToolCall> _parseToolCalls(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      final func = map['function'] as Map<String, dynamic>;
      return ToolCall(
        id: map['id'] as String,
        callType: map['type'] as String? ?? 'function',
        function: FunctionCall(
          name: func['name'] as String,
          arguments: func['arguments'] as String,
        ),
      );
    }).toList();
  }

  String _truncate(String s, int maxLength) {
    return s.length <= maxLength ? s : '${s.substring(0, maxLength)}...';
  }
}
