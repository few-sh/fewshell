import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:agent_core/agent_core.dart';
import 'package:llm_dart/llm_dart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Controller for remote session execution via WebSocket.
///
/// Handles communication with decamp-agent server for remote projects.
/// Supports:
/// - Agent loop execution (run, approve, cancel)
/// - Settings sync (get_settings, set_settings)
/// - Snippets sync (get_snippets, set_snippet, delete_snippet)
/// - Secrets sync (get_secrets, set_secret, delete_secret)
///
/// All data changes are broadcast by the server to all connected clients.
class RemoteSessionController {
  final String serverUrl;
  final String projectId;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  // Agent loop callbacks
  Completer<void>? _runCompleter;
  void Function(String delta)? _onTextDelta;
  Future<void> Function(ChatMessage)? _onAssistantMessage;
  Future<void> Function(ChatMessage)? _onToolResultMessage;
  Future<List<int>?> Function(List<Map<String, dynamic>>)? _requestApproval;
  void Function(String)? _onError;

  // Data sync callbacks (set these to receive updates)
  void Function(ProjectSettings)? onSettingsChanged;
  void Function(List<Snippet>)? onSnippetsChanged;
  void Function(List<SecretMetadata>)? onSecretsChanged;

  // Pending request completers
  Completer<ProjectSettings?>? _settingsCompleter;
  Completer<List<Snippet>>? _snippetsCompleter;
  Completer<List<SecretMetadata>>? _secretsCompleter;

  RemoteSessionController({required this.serverUrl, required this.projectId});

  /// Whether currently connected to server
  bool get isConnected => _channel != null;

  /// Connect to the WebSocket server
  Future<bool> connect() async {
    if (_channel != null) {
      return true; // Already connected
    }

    try {
      final wsUrl = _buildWebSocketUrl(serverUrl);
      developer.log('🔌 Connecting to $wsUrl', name: 'RemoteSession');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Wait for connection to be ready
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

  /// Disconnect from the server
  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _subscription = null;
    developer.log('🔌 Disconnected from server', name: 'RemoteSession');
  }

  /// Send a message and run the agent loop on the server
  ///
  /// Returns when the agent loop completes (done, cancelled, or error).
  Future<AgentLoopResult> sendMessage({
    required String sessionId,
    required List<ChatMessage> conversation,
    required String content,
    required void Function(String delta) onTextDelta,
    required Future<void> Function(ChatMessage) onAssistantMessage,
    required Future<void> Function(ChatMessage) onToolResultMessage,
    required Future<List<int>?> Function(List<Map<String, dynamic>>)
    requestApproval,
  }) async {
    if (_channel == null) {
      return AgentLoopError('Not connected to server');
    }

    // Store callbacks
    _onTextDelta = onTextDelta;
    _onAssistantMessage = onAssistantMessage;
    _onToolResultMessage = onToolResultMessage;
    _requestApproval = requestApproval;
    _runCompleter = Completer<void>();

    // Convert conversation to JSON
    final conversationJson = conversation
        .map((msg) => chatMessageToMap(msg, id: '', sessionId: ''))
        .toList();

    // Send run command with sessionId and projectId
    _send({
      'cmd': 'run',
      'sessionId': sessionId,
      'projectId': projectId,
      'conversation': conversationJson,
      'content': content,
    });

    developer.log('📤 Sent run command', name: 'RemoteSession');

    // Wait for completion
    try {
      await _runCompleter!.future;
      return AgentLoopCompleted();
    } catch (e) {
      if (e is _CancelledException) {
        return AgentLoopCancelled();
      }
      return AgentLoopError(e.toString());
    } finally {
      _clearCallbacks();
    }
  }

  // ============================================================
  // Settings API
  // ============================================================

  /// Get project settings from server
  Future<ProjectSettings?> getSettings() async {
    if (_channel == null) {
      final connected = await connect();
      if (!connected) return null;
    }

    _settingsCompleter = Completer<ProjectSettings?>();
    _send({'cmd': 'get_settings', 'projectId': projectId});

    try {
      return await _settingsCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
    } finally {
      _settingsCompleter = null;
    }
  }

  /// Save project settings to server
  Future<bool> saveSettings(ProjectSettings settings) async {
    if (_channel == null) {
      final connected = await connect();
      if (!connected) return false;
    }

    _send({
      'cmd': 'set_settings',
      'projectId': projectId,
      'settings': settings.toJson(),
    });

    return true;
  }

  // ============================================================
  // Snippets API
  // ============================================================

  /// Get snippets from server
  Future<List<Snippet>> getSnippets() async {
    if (_channel == null) {
      final connected = await connect();
      if (!connected) return [];
    }

    _snippetsCompleter = Completer<List<Snippet>>();
    _send({'cmd': 'get_snippets', 'projectId': projectId});

    try {
      return await _snippetsCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => [],
      );
    } finally {
      _snippetsCompleter = null;
    }
  }

  /// Save a snippet to server
  Future<bool> saveSnippet(Snippet snippet) async {
    if (_channel == null) {
      final connected = await connect();
      if (!connected) return false;
    }

    _send({'cmd': 'set_snippet', 'snippet': snippet.toJson()});
    return true;
  }

  /// Delete a snippet from server
  Future<bool> deleteSnippet(String snippetId) async {
    if (_channel == null) {
      final connected = await connect();
      if (!connected) return false;
    }

    _send({'cmd': 'delete_snippet', 'id': snippetId});
    return true;
  }

  // ============================================================
  // Secrets API
  // ============================================================

  /// Get secret metadata from server (values not included)
  Future<List<SecretMetadata>> getSecrets() async {
    if (_channel == null) {
      final connected = await connect();
      if (!connected) return [];
    }

    _secretsCompleter = Completer<List<SecretMetadata>>();
    _send({'cmd': 'get_secrets', 'projectId': projectId});

    try {
      return await _secretsCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => [],
      );
    } finally {
      _secretsCompleter = null;
    }
  }

  /// Save a secret to server
  Future<bool> saveSecret(String secretId, String name, String value) async {
    if (_channel == null) {
      final connected = await connect();
      if (!connected) return false;
    }

    _send({
      'cmd': 'set_secret',
      'projectId': projectId,
      'id': secretId,
      'name': name,
      'value': value,
    });
    return true;
  }

  /// Delete a secret from server
  Future<bool> deleteSecret(String secretId) async {
    if (_channel == null) {
      final connected = await connect();
      if (!connected) return false;
    }

    _send({'cmd': 'delete_secret', 'id': secretId});
    return true;
  }

  /// Handle incoming WebSocket message
  void _handleMessage(dynamic message) async {
    if (message is! String) return;

    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['t'] as String?;

      switch (type) {
        case 'connected':
          developer.log('🔌 Connected to server', name: 'RemoteSession');

        case 'delta':
          final delta = data['d'] as String? ?? '';
          _onTextDelta?.call(delta);

        case 'approval':
          await _handleApprovalRequest(data);

        case 'message':
          await _handleMessageReceived(data);

        case 'done':
          developer.log('✅ Agent loop completed', name: 'RemoteSession');
          _runCompleter?.complete();

        case 'cancelled':
          developer.log('🚫 Agent loop cancelled', name: 'RemoteSession');
          _runCompleter?.completeError(_CancelledException());

        case 'error':
          final errorMsg = data['msg'] as String? ?? 'Unknown error';
          developer.log('❌ Server error: $errorMsg', name: 'RemoteSession');
          _onError?.call(errorMsg);
          _runCompleter?.completeError(Exception(errorMsg));

        // Data sync events
        case 'settings':
          _handleSettingsReceived(data);

        case 'snippets':
          _handleSnippetsReceived(data);

        case 'secrets':
          _handleSecretsReceived(data);

        default:
          developer.log(
            '⚠️ Unknown message type: $type',
            name: 'RemoteSession',
          );
      }
    } catch (e) {
      developer.log('❌ Error handling message: $e', name: 'RemoteSession');
    }
  }

  /// Handle settings received from server
  void _handleSettingsReceived(Map<String, dynamic> data) {
    final settingsJson = data['settings'] as Map<String, dynamic>?;
    if (settingsJson == null) return;

    try {
      final settings = ProjectSettings.fromJson(settingsJson);

      // Complete pending request
      if (_settingsCompleter != null && !_settingsCompleter!.isCompleted) {
        _settingsCompleter!.complete(settings);
      }

      // Notify listeners (for real-time updates)
      onSettingsChanged?.call(settings);

      developer.log('📥 Settings received', name: 'RemoteSession');
    } catch (e) {
      developer.log('❌ Error parsing settings: $e', name: 'RemoteSession');
      _settingsCompleter?.complete(null);
    }
  }

  /// Handle snippets received from server
  void _handleSnippetsReceived(Map<String, dynamic> data) {
    final snippetsJson = data['snippets'] as List<dynamic>?;
    if (snippetsJson == null) return;

    try {
      final snippets = snippetsJson
          .map((s) => Snippet.fromJson(s as Map<String, dynamic>))
          .toList();

      // Complete pending request
      if (_snippetsCompleter != null && !_snippetsCompleter!.isCompleted) {
        _snippetsCompleter!.complete(snippets);
      }

      // Notify listeners
      onSnippetsChanged?.call(snippets);

      developer.log(
        '📥 Snippets received: ${snippets.length}',
        name: 'RemoteSession',
      );
    } catch (e) {
      developer.log('❌ Error parsing snippets: $e', name: 'RemoteSession');
      _snippetsCompleter?.complete([]);
    }
  }

  /// Handle secrets metadata received from server
  void _handleSecretsReceived(Map<String, dynamic> data) {
    final secretsJson = data['secrets'] as List<dynamic>?;
    if (secretsJson == null) return;

    try {
      final secrets = secretsJson
          .map((s) => SecretMetadata.fromJson(s as Map<String, dynamic>))
          .toList();

      // Complete pending request
      if (_secretsCompleter != null && !_secretsCompleter!.isCompleted) {
        _secretsCompleter!.complete(secrets);
      }

      // Notify listeners
      onSecretsChanged?.call(secrets);

      developer.log(
        '📥 Secrets received: ${secrets.length}',
        name: 'RemoteSession',
      );
    } catch (e) {
      developer.log('❌ Error parsing secrets: $e', name: 'RemoteSession');
      _secretsCompleter?.complete([]);
    }
  }

  /// Handle tool approval request from server
  Future<void> _handleApprovalRequest(Map<String, dynamic> data) async {
    final tools =
        (data['tools'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    developer.log(
      '🔧 Approval requested for ${tools.length} tools',
      name: 'RemoteSession',
    );

    if (_requestApproval == null) {
      // No approval callback - deny all
      _send({'cmd': 'cancel'});
      return;
    }

    final approvedIndices = await _requestApproval!(tools);

    if (approvedIndices == null) {
      // User cancelled
      _send({'cmd': 'cancel'});
    } else {
      // Send approved indices
      _send({'cmd': 'approve', 'approved': approvedIndices});
      developer.log(
        '✅ Approved ${approvedIndices.length} tools',
        name: 'RemoteSession',
      );
    }
  }

  /// Handle message received from server (assistant or tool result)
  Future<void> _handleMessageReceived(Map<String, dynamic> data) async {
    final role = data['role'] as String?;
    final msgData = data['msg'] as Map<String, dynamic>?;

    if (msgData == null) return;

    try {
      final chatMessage = mapToChatMessage(msgData);

      if (role == 'assistant') {
        await _onAssistantMessage?.call(chatMessage);
      } else if (role == 'tool') {
        await _onToolResultMessage?.call(chatMessage);
      }
    } catch (e) {
      developer.log('❌ Error parsing message: $e', name: 'RemoteSession');
    }
  }

  /// Handle WebSocket disconnect
  void _handleDisconnect() {
    developer.log('🔌 WebSocket disconnected', name: 'RemoteSession');
    _channel = null;
    _subscription = null;

    // Complete any pending run with error
    if (_runCompleter != null && !_runCompleter!.isCompleted) {
      _runCompleter!.completeError(Exception('Connection lost'));
    }
  }

  /// Send JSON message to server
  void _send(Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode(data));
  }

  /// Clear callbacks after run completes
  void _clearCallbacks() {
    _onTextDelta = null;
    _onAssistantMessage = null;
    _onToolResultMessage = null;
    _requestApproval = null;
    _onError = null;
    _runCompleter = null;
  }

  /// Build WebSocket URL from server URL
  String _buildWebSocketUrl(String baseUrl) {
    var url = baseUrl;

    // Convert http:// to ws:// or https:// to wss://
    if (url.startsWith('http://')) {
      url = 'ws://${url.substring(7)}';
    } else if (url.startsWith('https://')) {
      url = 'wss://${url.substring(8)}';
    } else if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
      url = 'ws://$url';
    }

    // Add /ws path if not present
    if (!url.endsWith('/ws')) {
      url = url.endsWith('/') ? '${url}ws' : '$url/ws';
    }

    return url;
  }
}

/// Exception for cancelled operations
class _CancelledException implements Exception {}
