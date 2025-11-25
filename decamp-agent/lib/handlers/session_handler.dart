import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:llm_dart/llm_dart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Handles a session's agent loop via WebSocket
///
/// The server is a thin transport layer. It:
/// 1. Receives conversation + user message from client
/// 2. Runs agent loop with streaming callbacks to client
/// 3. Sends back messages for client to persist
///
/// Protocol:
/// Client → Server:
///   {"cmd": "run", "conversation": [...], "content": "user message"}
///   {"cmd": "approve", "approved": [0, 1, 2]}  // indices to approve
///   {"cmd": "cancel"}
///
/// Server → Client:
///   {"t": "delta", "d": "streaming text..."}
///   {"t": "approval", "tools": [{index, id, name, args}, ...]}
///   {"t": "message", "msg": {...}}  // assistant or tool result message
///   {"t": "done"}
///   {"t": "error", "msg": "..."}
class SessionHandler {
  final WebSocketChannel _webSocket;

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
  }

  Future<void> _handleMessage(dynamic message) async {
    if (message is! String) {
      _sendError('Invalid message format');
      return;
    }

    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final cmd = data['cmd'] as String?;

      switch (cmd) {
        case 'run':
          await _handleRun(data);

        case 'approve':
          _handleApprove(data);

        case 'cancel':
          _handleCancel();

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

  /// Creates LLM client from environment
  Future<ChatCapability?> _createLlmClient() async {
    final apiKey = Platform.environment['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      developer.log(
        '⚠️ OPENAI_API_KEY not set',
        name: 'SessionHandler',
      );
      return null;
    }

    final model = Platform.environment['OPENAI_MODEL'] ?? 'gpt-4o-mini';

    return await LLMBuilder().openai().apiKey(apiKey).model(model).build();
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
}
