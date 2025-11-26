import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:llm_dart/llm_dart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'connection_manager.dart';

/// Handles a session's agent loop via WebSocket
///
/// The server is a thin transport layer. It:
/// 1. Receives conversation + user message from client
/// 2. Runs agent loop with streaming callbacks to client
/// 3. Sends back messages for client to persist
///
/// Protocol:
/// Client → Server:
///   {"cmd": "run", "projectId": "...", "conversation": [...], "content": "user message"}
///   {"cmd": "approve", "approved": [0, 1, 2]}  // indices to approve
///   {"cmd": "cancel"}
///   {"cmd": "get_settings", "projectId": "..."}
///   {"cmd": "set_settings", "projectId": "...", "settings": {...}}
///   {"cmd": "get_snippets", "projectId": "..."}
///   {"cmd": "set_snippet", "snippet": {...}}
///   {"cmd": "delete_snippet", "id": "..."}
///   {"cmd": "get_secrets", "projectId": "..."}
///   {"cmd": "set_secret", "projectId": "...", "id": "...", "name": "...", "value": "..."}
///   {"cmd": "delete_secret", "id": "..."}
///
/// Server → Client:
///   {"t": "delta", "d": "streaming text..."}
///   {"t": "approval", "tools": [{index, id, name, args}, ...]}
///   {"t": "message", "msg": {...}}  // assistant or tool result message
///   {"t": "done"}
///   {"t": "settings", "settings": {...}}
///   {"t": "snippets", "snippets": [...]}
///   {"t": "secrets", "secrets": [...]}  // metadata only, no values
///   {"t": "error", "msg": "..."}
class SessionHandler {
  final WebSocketChannel _webSocket;
  final ConnectionManager _connManager = ConnectionManager.instance;

  /// Current project ID (set on first command that includes projectId)
  String? _projectId;

  Completer<List<int>?>? _approvalCompleter;
  StreamSubscription<dynamic>? _subscription;

  /// Shared fetch executor (stateless, can be reused)
  final FetchExecutor _fetchExecutor = FetchExecutor();

  /// SSH executor (per-session, maintains connection state)
  /// Initialized when client provides SSH settings
  ShellExecutor? _shellExecutor;

  SessionHandler(this._webSocket);

  /// Starts listening for commands on the WebSocket
  void start() {
    _subscription = _webSocket.stream.listen(
      _handleMessage,
      onDone: _cleanup,
      onError: (dynamic error) {
        developer.log('❌ WebSocket error: $error', name: 'SessionHandler');
        _cleanup();
      },
    );
  }

  void _cleanup() {
    _subscription?.cancel();
    _approvalCompleter?.complete(null);
    _connManager.unregisterClient(_webSocket);
  }

  /// Register this client for a project (call when projectId is first seen)
  void _ensureRegistered(String projectId) {
    if (_projectId != projectId) {
      if (_projectId != null) {
        _connManager.unregisterClient(_webSocket);
      }
      _projectId = projectId;
      _connManager.registerClient(_webSocket, projectId);
      developer.log('📋 Client registered for project: $projectId',
          name: 'SessionHandler');
    }
  }

  Future<void> _handleMessage(dynamic message) async {
    if (message is! String) {
      _sendError('Invalid message format');
      return;
    }

    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final cmd = data['cmd'] as String?;

      // Extract projectId if present
      final projectId = data['projectId'] as String?;
      if (projectId != null) {
        _ensureRegistered(projectId);
      }

      switch (cmd) {
        case 'run':
          await _handleRun(data);

        case 'approve':
          _handleApprove(data);

        case 'cancel':
          _handleCancel();

        // Settings commands
        case 'get_settings':
          await _handleGetSettings(data);

        case 'set_settings':
          await _handleSetSettings(data);

        // Snippets commands
        case 'get_snippets':
          await _handleGetSnippets(data);

        case 'set_snippet':
          await _handleSetSnippet(data);

        case 'delete_snippet':
          await _handleDeleteSnippet(data);

        // Secrets commands
        case 'get_secrets':
          await _handleGetSecrets(data);

        case 'set_secret':
          await _handleSetSecret(data);

        case 'delete_secret':
          await _handleDeleteSecret(data);

        default:
          _sendError('Unknown command: $cmd');
      }
    } catch (e) {
      developer.log('❌ Error handling message: $e', name: 'SessionHandler');
      _sendError('Failed to process message: $e');
    }
  }

  /// Handles the "run" command
  /// Client sends conversation history + new user message
  Future<void> _handleRun(Map<String, dynamic> data) async {
    // Parse conversation from client
    final conversationJson = data['conversation'] as List<dynamic>?;
    final userContent = data['content'] as String?;

    if (userContent == null || userContent.isEmpty) {
      _sendError('Message content required');
      return;
    }

    // Convert conversation from JSON to ChatMessage list
    final conversation = <ChatMessage>[];
    if (conversationJson != null) {
      for (final item in conversationJson) {
        try {
          conversation.add(mapToChatMessage(item as Map<String, dynamic>));
        } catch (e) {
          developer.log(
            '⚠️ Skipping invalid message: $e',
            name: 'SessionHandler',
          );
        }
      }
    }

    // Add the new user message
    conversation.add(ChatMessage.user(userContent));

    // Get LLM client
    final llm = await _createLlmClient();
    if (llm == null) {
      _sendError(
        'LLM not configured - please configure it via the LLM settings',
      );
      return;
    }

    // Run the agent loop with WebSocket callbacks
    final result = await runAgentLoop(
      llmStream: (conv, tools) => llm.chatStream(conv, tools: tools),
      tools: shellTools,
      conversation: conversation,
      requestApproval: _requestApproval,
      executeToolCall: _executeToolCall,
      onTextDelta: (delta) => _send({'t': 'delta', 'd': delta}),
      onAssistantMessage: (msg) async {
        _send({
          't': 'message',
          'role': 'assistant',
          'msg': chatMessageToMap(msg, id: _generateId(), sessionId: ''),
        });
      },
      onToolResultMessage: (msg) async {
        _send({
          't': 'message',
          'role': 'tool',
          'msg': chatMessageToMap(msg, id: _generateId(), sessionId: ''),
        });
      },
    );

    // Send completion status
    switch (result) {
      case AgentLoopCompleted():
        _send({'t': 'done'});

      case AgentLoopCancelled():
        _send({'t': 'cancelled'});

      case AgentLoopError(message: final msg):
        _sendError(msg);
    }
  }

  /// Handles the "approve" command
  void _handleApprove(Map<String, dynamic> data) {
    final completer = _approvalCompleter;
    if (completer == null) {
      _sendError('No approval pending');
      return;
    }

    final approved = (data['approved'] as List<dynamic>?)?.cast<int>() ?? [];
    completer.complete(approved);
    _approvalCompleter = null;
  }

  /// Handles the "cancel" command
  void _handleCancel() {
    final completer = _approvalCompleter;
    if (completer == null) {
      _sendError('No approval pending');
      return;
    }

    completer.complete(null);
    _approvalCompleter = null;
  }

  /// Requests approval for tool calls via WebSocket
  Future<List<PendingToolCall>?> _requestApproval(
    List<PendingToolCall> toolCalls,
  ) async {
    _approvalCompleter = Completer<List<int>?>();

    // Send approval request to client
    _send({
      't': 'approval',
      'tools': toolCalls.indexed.map((indexed) {
        final (index, tc) = indexed;
        return {
          'index': index,
          'id': tc.id,
          'name': tc.name,
          'args': tc.arguments,
        };
      }).toList(),
    });

    // Wait for client response (list of approved indices)
    final approvedIndices = await _approvalCompleter!.future;

    if (approvedIndices == null) {
      return null; // Cancelled
    }

    // Return only the approved tool calls
    return approvedIndices
        .where((i) => i >= 0 && i < toolCalls.length)
        .map((i) => toolCalls[i])
        .toList();
  }

  /// Executes a tool call on the server
  Future<String> _executeToolCall(ToolCall toolCall) async {
    final name = toolCall.function.name;
    final argsJson = toolCall.function.arguments;

    try {
      final args = argsJson.isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(argsJson))
          : <String, dynamic>{};

      switch (name) {
        case kExecuteShellCommand:
          return await _executeShell(args);

        case kFetch:
          return await _executeFetch(args);

        default:
          return jsonEncode({'error': 'Unknown tool: $name'});
      }
    } catch (e) {
      return jsonEncode({'error': 'Tool execution failed: $e'});
    }
  }

  /// Executes a shell command
  ///
  /// Uses SSH if configured, otherwise falls back to local execution
  Future<String> _executeShell(Map<String, dynamic> args) async {
    final command = args['command'] as String? ?? '';
    final sudoRequired = args['sudo_required'] as bool? ?? false;
    final secrets = args['secrets'] as Map<String, dynamic>?;

    if (command.isEmpty) {
      return jsonEncode({'error': 'Command is required'});
    }

    // If SSH executor is configured, use it
    if (_shellExecutor != null) {
      final result = sudoRequired
          ? await _shellExecutor!.executeWithSudo(
              command: command,
              secrets: secrets?.map((k, v) => MapEntry(k, v.toString())),
            )
          : await _shellExecutor!.executeCommand(
              command: command,
              secrets: secrets?.map((k, v) => MapEntry(k, v.toString())),
            );

      return jsonEncode(result);
    }

    // Fall back to local execution (no SSH)
    try {
      final actualCommand = sudoRequired ? 'sudo $command' : command;

      final result = await Process.run(
        '/bin/sh',
        ['-c', actualCommand],
        environment: Platform.environment,
      );

      return jsonEncode({
        'executed': true,
        'stdout': result.stdout as String,
        'stderr': result.stderr as String,
        'exitCode': result.exitCode,
      });
    } catch (e) {
      return jsonEncode({
        'executed': false,
        'error': 'Failed to execute command: $e',
      });
    }
  }

  /// Executes an HTTP fetch request using shared FetchExecutor
  Future<String> _executeFetch(Map<String, dynamic> args) async {
    final url = args['url'] as String?;
    if (url == null) {
      return jsonEncode({'error': 'URL is required'});
    }

    final method = (args['method'] as String?) ?? 'GET';
    final headers = args['headers'] as Map<String, dynamic>?;
    final body = args['body'] as String?;
    final timeout = (args['timeout'] as num?)?.toInt() ?? 30;

    final result = await _fetchExecutor.execute(
      url: url,
      method: method,
      headers: headers?.map((k, v) => MapEntry(k, v.toString())),
      body: body,
      timeoutSeconds: timeout,
    );

    // Flatten the result for the tool response
    final data = result['data'] as Map<String, dynamic>? ?? {};
    if (result['success'] == true) {
      return jsonEncode({
        'statusCode': data['statusCode'],
        'headers': data['headers'],
        'body': data['body'],
      });
    } else {
      return jsonEncode({
        'error': result['error'] ?? 'Fetch failed',
        'statusCode': data['statusCode'] ?? 0,
      });
    }
  }

  /// Creates LLM client from project settings
  Future<ChatCapability?> _createLlmClient() async {
    if (_projectId == null) {
      developer.log('⚠️ No project ID set', name: 'SessionHandler');
      return null;
    }

    // Get project settings from TOML store
    final settings = await _connManager.dataStore.getSettings(_projectId!);
    if (settings == null) {
      developer.log(
        '⚠️ No settings found for project: $_projectId',
        name: 'SessionHandler',
      );
      return null;
    }

    // Get the default LLM configuration
    final llmConfig = settings.defaultLlm;
    if (llmConfig == null) {
      developer.log(
        '⚠️ No LLM configured for project: $_projectId',
        name: 'SessionHandler',
      );
      return null;
    }

    // Get API key from secrets
    String? apiKey;
    if (llmConfig.apiKeySecretId != null) {
      apiKey = await _connManager.dataStore.getSecretValue(
        llmConfig.apiKeySecretId!,
      );
    }

    if (apiKey == null || apiKey.isEmpty) {
      developer.log(
        '⚠️ No API key found for LLM: ${llmConfig.identifier}',
        name: 'SessionHandler',
      );
      return null;
    }

    developer.log(
      '🤖 Creating LLM client: ${llmConfig.provider}/${llmConfig.model}',
      name: 'SessionHandler',
    );

    // Build LLM client based on provider
    final builder = LLMBuilder();

    switch (llmConfig.provider.toLowerCase()) {
      case 'openai':
        builder.openai();
      case 'anthropic':
        builder.anthropic();
      case 'google':
        builder.google();
      case 'openrouter':
        builder.openRouter();
      default:
        // Default to OpenAI-compatible with custom base URL
        builder.openai();
    }

    builder.apiKey(apiKey).model(llmConfig.model);

    // Set base URL if provided
    if (llmConfig.baseUrl.isNotEmpty) {
      builder.baseUrl(llmConfig.baseUrl);
    }

    // Set optional parameters
    if (llmConfig.maxTokens != null) {
      builder.maxTokens(llmConfig.maxTokens!);
    }
    if (llmConfig.temperature != null) {
      builder.temperature(llmConfig.temperature!);
    }

    return await builder.build();
  }

  void _send(Map<String, dynamic> data) {
    _webSocket.sink.add(jsonEncode(data));
  }

  void _sendError(String message) {
    _send({'t': 'error', 'msg': message});
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond % 1000}';
  }

  // ============================================================
  // Settings Handlers
  // ============================================================

  Future<void> _handleGetSettings(Map<String, dynamic> data) async {
    final projectId = data['projectId'] as String?;
    if (projectId == null) {
      _sendError('projectId required');
      return;
    }

    final settings = await _connManager.dataStore.getSettings(projectId);
    if (settings != null) {
      _send({'t': 'settings', 'settings': settings.toJson()});
    } else {
      // Send empty settings for new project
      _send({
        't': 'settings',
        'settings': ProjectSettings(
          projectId: projectId,
          name: 'New Project',
        ).toJson(),
      });
    }
  }

  Future<void> _handleSetSettings(Map<String, dynamic> data) async {
    final projectId = data['projectId'] as String?;
    final settingsJson = data['settings'] as Map<String, dynamic>?;

    if (projectId == null || settingsJson == null) {
      _sendError('projectId and settings required');
      return;
    }

    try {
      final settings = ProjectSettings.fromJson({
        ...settingsJson,
        'projectId': projectId,
      });
      await _connManager.dataStore.saveSettings(settings);

      // Broadcast to all clients (including sender)
      _connManager.broadcastToProjectAll(projectId, {
        't': 'settings',
        'settings': settings.toJson(),
      });

      developer.log('💾 Settings saved for project: $projectId',
          name: 'SessionHandler');
    } catch (e) {
      _sendError('Failed to save settings: $e');
    }
  }

  // ============================================================
  // Snippets Handlers
  // ============================================================

  Future<void> _handleGetSnippets(Map<String, dynamic> data) async {
    final projectId = data['projectId'] as String?;
    if (projectId == null) {
      _sendError('projectId required');
      return;
    }

    final snippets = await _connManager.dataStore.getSnippets(projectId);
    _send({
      't': 'snippets',
      'snippets': snippets.map((s) => s.toJson()).toList(),
    });
  }

  Future<void> _handleSetSnippet(Map<String, dynamic> data) async {
    final snippetJson = data['snippet'] as Map<String, dynamic>?;
    if (snippetJson == null) {
      _sendError('snippet required');
      return;
    }

    try {
      final snippet = Snippet.fromJson(snippetJson);
      await _connManager.dataStore.saveSnippet(snippet);

      final projectId = snippet.projectId ?? _projectId;
      if (projectId != null) {
        // Broadcast updated snippets list
        final snippets = await _connManager.dataStore.getSnippets(projectId);
        _connManager.broadcastToProjectAll(projectId, {
          't': 'snippets',
          'snippets': snippets.map((s) => s.toJson()).toList(),
        });
      }

      developer.log('💾 Snippet saved: ${snippet.id}', name: 'SessionHandler');
    } catch (e) {
      _sendError('Failed to save snippet: $e');
    }
  }

  Future<void> _handleDeleteSnippet(Map<String, dynamic> data) async {
    final snippetId = data['id'] as String?;
    if (snippetId == null) {
      _sendError('id required');
      return;
    }

    await _connManager.dataStore.deleteSnippet(snippetId);

    // Broadcast deletion to current project
    if (_projectId != null) {
      final snippets = await _connManager.dataStore.getSnippets(_projectId!);
      _connManager.broadcastToProjectAll(_projectId!, {
        't': 'snippets',
        'snippets': snippets.map((s) => s.toJson()).toList(),
      });
    }

    developer.log('🗑️ Snippet deleted: $snippetId', name: 'SessionHandler');
  }

  // ============================================================
  // Secrets Handlers
  // ============================================================

  Future<void> _handleGetSecrets(Map<String, dynamic> data) async {
    final projectId = data['projectId'] as String?;
    if (projectId == null) {
      _sendError('projectId required');
      return;
    }

    // Return metadata only, never values
    final secrets = await _connManager.dataStore.getSecretMetadata(projectId);
    _send({
      't': 'secrets',
      'secrets': secrets.map((s) => s.toJson()).toList(),
    });
  }

  Future<void> _handleSetSecret(Map<String, dynamic> data) async {
    final projectId = data['projectId'] as String?;
    final secretId = data['id'] as String?;
    final name = data['name'] as String?;
    final value = data['value'] as String?;

    if (projectId == null ||
        secretId == null ||
        name == null ||
        value == null) {
      _sendError('projectId, id, name, and value required');
      return;
    }

    await _connManager.dataStore.saveSecret(projectId, secretId, name, value);

    // Broadcast updated secrets metadata (not values!)
    final secrets = await _connManager.dataStore.getSecretMetadata(projectId);
    _connManager.broadcastToProjectAll(projectId, {
      't': 'secrets',
      'secrets': secrets.map((s) => s.toJson()).toList(),
    });

    developer.log('💾 Secret saved: $secretId', name: 'SessionHandler');
  }

  Future<void> _handleDeleteSecret(Map<String, dynamic> data) async {
    final secretId = data['id'] as String?;
    if (secretId == null) {
      _sendError('id required');
      return;
    }

    await _connManager.dataStore.deleteSecret(secretId);

    // Broadcast deletion to current project
    if (_projectId != null) {
      final secrets =
          await _connManager.dataStore.getSecretMetadata(_projectId!);
      _connManager.broadcastToProjectAll(_projectId!, {
        't': 'secrets',
        'secrets': secrets.map((s) => s.toJson()).toList(),
      });
    }

    developer.log('🗑️ Secret deleted: $secretId', name: 'SessionHandler');
  }
}
