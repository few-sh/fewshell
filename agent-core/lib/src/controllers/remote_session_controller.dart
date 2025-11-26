import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:llm_dart/llm_dart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/message.dart';
import '../models/session.dart';
import 'session_controller.dart';

/// Remote implementation of SessionController.
///
/// This is the "multiplayer" mode: communicates with decamp-agent server
/// via WebSocket. Server is source of truth for all data.
///
/// Key insight: Same reactive stream pattern as LocalSessionController,
/// but streams fire when server pushes updates instead of on local writes.
class RemoteSessionController implements SessionController {
  @override
  final String projectId;

  final String serverUrl;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  // Stream controllers for reactive updates
  final _sessionControllers = <String, StreamController<List<Session>>>{};
  final _messageControllers = <String, StreamController<List<Message>>>{};

  // Pending request completers
  final _pendingRequests = <String, Completer<dynamic>>{};
  int _requestId = 0;

  // Agent loop state
  Completer<AgentLoopResult>? _runCompleter;
  void Function(String)? _onTextDelta;
  void Function(Message)? _onMessage;
  Future<List<int>?> Function(List<PendingToolCall>)? _requestApproval;

  RemoteSessionController({
    required this.projectId,
    required this.serverUrl,
  });

  @override
  bool get isConnected => _channel != null;

  @override
  Future<bool> connect() async {
    if (_channel != null) return true;

    try {
      final wsUrl = _buildWebSocketUrl(serverUrl);
      developer.log('🔌 Connecting to $wsUrl', name: 'RemoteSession');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: (error) {
          developer.log('❌ WebSocket error: $error', name: 'RemoteSession');
          _handleDisconnect();
        },
      );

      developer.log('✅ Connected to server', name: 'RemoteSession');
      return true;
    } catch (e) {
      developer.log('❌ Connection failed: $e', name: 'RemoteSession');
      _channel = null;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _subscription = null;
    developer.log('🔌 Disconnected from server', name: 'RemoteSession');
  }

  @override
  void dispose() {
    disconnect();
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
    return _getOrCreateSessionStream('all');
  }

  @override
  Stream<List<Session>> watchActiveSessions() {
    return _getOrCreateSessionStream('active');
  }

  @override
  Stream<List<Session>> watchArchivedSessions() {
    return _getOrCreateSessionStream('archived');
  }

  Stream<List<Session>> _getOrCreateSessionStream(String key) {
    final fullKey = '$projectId:$key';
    if (!_sessionControllers.containsKey(fullKey)) {
      final controller = StreamController<List<Session>>.broadcast(
        onListen: () => _fetchAndEmitSessions(key),
      );
      _sessionControllers[fullKey] = controller;
    }
    return _sessionControllers[fullKey]!.stream;
  }

  Future<void> _fetchAndEmitSessions(String key) async {
    if (!isConnected) await connect();

    _send({'cmd': 'get_sessions', 'projectId': projectId, 'filter': key});
  }

  // ============================================================
  // Sessions - CRUD
  // ============================================================

  @override
  Future<Session?> getSession(String sessionId) async {
    if (!isConnected) await connect();

    final id = _nextRequestId();
    final completer = Completer<Session?>();
    _pendingRequests[id] = completer;

    _send({'cmd': 'get_session', 'sessionId': sessionId, 'reqId': id});

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pendingRequests.remove(id);
        return null;
      },
    );
  }

  @override
  Future<Session> createSession({String? description}) async {
    if (!isConnected) await connect();

    final id = _nextRequestId();
    final completer = Completer<Session>();
    _pendingRequests[id] = completer;

    _send({
      'cmd': 'create_session',
      'projectId': projectId,
      'description': description ?? '',
      'reqId': id,
    });

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pendingRequests.remove(id);
        throw Exception('Create session timed out');
      },
    );
  }

  @override
  Future<void> updateSessionDescription(
    String sessionId,
    String description,
  ) async {
    if (!isConnected) await connect();

    _send({
      'cmd': 'update_session',
      'sessionId': sessionId,
      'description': description,
    });
  }

  @override
  Future<void> setSessionArchived(String sessionId, bool archived) async {
    if (!isConnected) await connect();

    _send({
      'cmd': 'update_session',
      'sessionId': sessionId,
      'isArchived': archived,
    });
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    if (!isConnected) await connect();

    _send({'cmd': 'delete_session', 'sessionId': sessionId});
  }

  // ============================================================
  // Messages - Reactive Streams
  // ============================================================

  @override
  Stream<List<Message>> watchMessages(String sessionId) {
    if (!_messageControllers.containsKey(sessionId)) {
      final controller = StreamController<List<Message>>.broadcast(
        onListen: () => _fetchAndEmitMessages(sessionId),
      );
      _messageControllers[sessionId] = controller;
    }
    return _messageControllers[sessionId]!.stream;
  }

  Future<void> _fetchAndEmitMessages(String sessionId) async {
    if (!isConnected) await connect();

    _send({'cmd': 'get_messages', 'sessionId': sessionId});
  }

  // ============================================================
  // Messages - CRUD
  // ============================================================

  @override
  Future<List<Message>> getMessages(String sessionId) async {
    if (!isConnected) await connect();

    final id = _nextRequestId();
    final completer = Completer<List<Message>>();
    _pendingRequests[id] = completer;

    _send({'cmd': 'get_messages', 'sessionId': sessionId, 'reqId': id});

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pendingRequests.remove(id);
        return [];
      },
    );
  }

  @override
  Future<int> getMessageCount(String sessionId) async {
    final messages = await getMessages(sessionId);
    return messages.length;
  }

  @override
  Future<Message?> getMessage(String messageId) async {
    if (!isConnected) await connect();

    final id = _nextRequestId();
    final completer = Completer<Message?>();
    _pendingRequests[id] = completer;

    _send({'cmd': 'get_message', 'messageId': messageId, 'reqId': id});

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pendingRequests.remove(id);
        return null;
      },
    );
  }

  @override
  Future<void> updateMessageContent(String messageId, String newContent) async {
    if (!isConnected) await connect();

    _send({
      'cmd': 'update_message',
      'messageId': messageId,
      'content': newContent,
    });
  }

  @override
  Future<int> deleteMessagesAfter(
    String sessionId,
    DateTime afterTimestamp,
  ) async {
    if (!isConnected) await connect();

    final id = _nextRequestId();
    final completer = Completer<int>();
    _pendingRequests[id] = completer;

    _send({
      'cmd': 'delete_messages_after',
      'sessionId': sessionId,
      'afterTimestamp': afterTimestamp.millisecondsSinceEpoch,
      'reqId': id,
    });

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pendingRequests.remove(id);
        return 0;
      },
    );
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
    if (!isConnected) {
      final connected = await connect();
      if (!connected) {
        return AgentLoopError('Failed to connect to server');
      }
    }

    // Store callbacks
    _onTextDelta = onTextDelta;
    _onMessage = onMessage;
    _requestApproval = requestApproval;
    _runCompleter = Completer<AgentLoopResult>();

    // Send run command
    _send({
      'cmd': 'run',
      'projectId': projectId,
      'sessionId': sessionId,
      'content': content,
    });

    developer.log('📤 Sent run command', name: 'RemoteSession');

    return _runCompleter!.future;
  }

  @override
  Future<AgentLoopResult> continueConversation({
    required String sessionId,
    required void Function(String delta) onTextDelta,
    required void Function(Message message) onMessage,
    required Future<List<int>?> Function(List<PendingToolCall> tools)
        requestApproval,
  }) async {
    if (!isConnected) {
      final connected = await connect();
      if (!connected) {
        return AgentLoopError('Failed to connect to server');
      }
    }

    // Store callbacks
    _onTextDelta = onTextDelta;
    _onMessage = onMessage;
    _requestApproval = requestApproval;
    _runCompleter = Completer<AgentLoopResult>();

    // Send continue command (no content)
    _send({
      'cmd': 'continue',
      'projectId': projectId,
      'sessionId': sessionId,
    });

    developer.log('📤 Sent continue command', name: 'RemoteSession');

    return _runCompleter!.future;
  }

  @override
  void approvePendingTools(List<int> indices) {
    _send({'cmd': 'approve', 'approved': indices});
  }

  @override
  void cancel() {
    _send({'cmd': 'cancel'});
  }

  // ============================================================
  // WebSocket Handling
  // ============================================================

  void _handleMessage(dynamic data) async {
    if (data is! String) return;

    try {
      final msg = jsonDecode(data) as Map<String, dynamic>;
      final type = msg['t'] as String?;

      switch (type) {
        // Agent loop events
        case 'delta':
          _onTextDelta?.call(msg['d'] as String? ?? '');

        case 'approval':
          await _handleApprovalRequest(msg);

        case 'message':
          _handleMessageReceived(msg);

        case 'done':
          _runCompleter?.complete(AgentLoopCompleted());
          _clearCallbacks();

        case 'cancelled':
          _runCompleter?.complete(AgentLoopCancelled());
          _clearCallbacks();

        case 'error':
          final errorMsg = msg['msg'] as String? ?? 'Unknown error';
          _runCompleter?.complete(AgentLoopError(errorMsg));
          _clearCallbacks();

        // Session events
        case 'sessions':
          _handleSessionsReceived(msg);

        case 'session_created':
          _handleSessionCreated(msg);

        case 'session_updated':
          _handleSessionUpdated(msg);

        case 'session_deleted':
          _handleSessionDeleted(msg);

        // Message events
        case 'messages':
          _handleMessagesReceived(msg);
      }
    } catch (e) {
      developer.log('❌ Error handling message: $e', name: 'RemoteSession');
    }
  }

  Future<void> _handleApprovalRequest(Map<String, dynamic> msg) async {
    final toolsJson = msg['tools'] as List<dynamic>? ?? [];
    final tools = toolsJson.asMap().entries.map((entry) {
      final t = entry.value as Map<String, dynamic>;
      return PendingToolCall(
        id: t['id'] as String? ?? '',
        name: t['name'] as String? ?? '',
        arguments: t['args'] as Map<String, dynamic>? ?? {},
        originalToolCall: ToolCall(
          id: t['id'] as String? ?? '',
          callType: 'function',
          function: FunctionCall(
            name: t['name'] as String? ?? '',
            arguments: jsonEncode(t['args'] ?? {}),
          ),
        ),
      );
    }).toList();

    final approved = await _requestApproval?.call(tools);
    if (approved == null) {
      _send({'cmd': 'cancel'});
    } else {
      _send({'cmd': 'approve', 'approved': approved});
    }
  }

  void _handleMessageReceived(Map<String, dynamic> msg) {
    final msgData = msg['msg'] as Map<String, dynamic>?;
    if (msgData == null) return;

    final message = Message.fromJson(msgData);
    _onMessage?.call(message);

    // Also update the message stream for this session
    final sessionId = message.sessionId;
    _fetchAndEmitMessages(sessionId);
  }

  void _handleSessionsReceived(Map<String, dynamic> msg) {
    final sessionsJson = msg['sessions'] as List<dynamic>? ?? [];
    final sessions = sessionsJson
        .map((s) => Session.fromJson(s as Map<String, dynamic>))
        .toList();

    // Update all session streams
    for (final entry in _sessionControllers.entries) {
      if (entry.key.startsWith(projectId)) {
        entry.value.add(sessions);
      }
    }

    // Handle pending request
    final reqId = msg['reqId'] as String?;
    if (reqId != null) {
      final completer = _pendingRequests.remove(reqId);
      completer?.complete(sessions);
    }
  }

  void _handleSessionCreated(Map<String, dynamic> msg) {
    final sessionJson = msg['session'] as Map<String, dynamic>?;
    if (sessionJson == null) return;

    final session = Session.fromJson(sessionJson);

    // Handle pending request
    final reqId = msg['reqId'] as String?;
    if (reqId != null) {
      final completer = _pendingRequests.remove(reqId);
      completer?.complete(session);
    }

    // Refresh session streams
    _fetchAndEmitSessions('all');
    _fetchAndEmitSessions('active');
  }

  void _handleSessionUpdated(Map<String, dynamic> msg) {
    // Refresh session streams
    _fetchAndEmitSessions('all');
    _fetchAndEmitSessions('active');
    _fetchAndEmitSessions('archived');
  }

  void _handleSessionDeleted(Map<String, dynamic> msg) {
    final sessionId = msg['sessionId'] as String?;
    if (sessionId != null) {
      // Clear messages for this session
      _messageControllers[sessionId]?.add([]);
    }

    // Refresh session streams
    _fetchAndEmitSessions('all');
    _fetchAndEmitSessions('active');
    _fetchAndEmitSessions('archived');
  }

  void _handleMessagesReceived(Map<String, dynamic> msg) {
    final sessionId = msg['sessionId'] as String?;
    if (sessionId == null) return;

    final messagesJson = msg['messages'] as List<dynamic>? ?? [];
    final messages = messagesJson
        .map((m) => Message.fromJson(m as Map<String, dynamic>))
        .toList();

    // Update the message stream
    _messageControllers[sessionId]?.add(messages);

    // Handle pending request
    final reqId = msg['reqId'] as String?;
    if (reqId != null) {
      final completer = _pendingRequests.remove(reqId);
      completer?.complete(messages);
    }
  }

  void _handleDisconnect() {
    _channel = null;
    _subscription = null;

    // Complete any pending run with error
    _runCompleter?.complete(AgentLoopError('Disconnected from server'));
    _clearCallbacks();

    developer.log('🔌 Disconnected from server', name: 'RemoteSession');
  }

  void _clearCallbacks() {
    _runCompleter = null;
    _onTextDelta = null;
    _onMessage = null;
    _requestApproval = null;
  }

  // ============================================================
  // Helpers
  // ============================================================

  void _send(Map<String, dynamic> data) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode(data));
  }

  String _nextRequestId() => 'req_${_requestId++}';

  String _buildWebSocketUrl(String url) {
    var wsUrl = url;
    if (wsUrl.startsWith('http://')) {
      wsUrl = 'ws://${wsUrl.substring(7)}';
    } else if (wsUrl.startsWith('https://')) {
      wsUrl = 'wss://${wsUrl.substring(8)}';
    } else if (!wsUrl.startsWith('ws://') && !wsUrl.startsWith('wss://')) {
      wsUrl = 'ws://$wsUrl';
    }
    if (!wsUrl.endsWith('/ws')) {
      wsUrl = '$wsUrl/ws';
    }
    return '$wsUrl?projectId=$projectId';
  }
}
