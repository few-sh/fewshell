import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:crdt_sync/crdt_sync.dart';
import 'package:agent_core/agent_core.dart';
import 'package:llm_dart/llm_dart.dart';
import '../services/database_manager.dart';

class SyncController {
  final DatabaseManager dbManager;

  SyncController(this.dbManager);

  Handler get handler {
    return (Request request) {
      final path = request.url.path;

      if (path == 'global') {
        return webSocketHandler((WebSocketChannel channel, String? protocol) {
          final multiplexed = MultiplexedWebSocketChannel(channel);
          _setupCustomMessageHandling(multiplexed, 'Global');
          CrdtSync.server(dbManager.globalDatabase.crdt, multiplexed);
        })(request);
      } else if (path.startsWith('project/')) {
        final segments = path.split('/');
        if (segments.length >= 2) {
          final projectId = segments[1];
          return webSocketHandler(
              (WebSocketChannel channel, String? protocol) async {
            final db = await dbManager.getProjectDatabase(projectId);
            final multiplexed = MultiplexedWebSocketChannel(channel);
            _setupCustomMessageHandling(multiplexed, 'Project', db);
            CrdtSync.server(db.crdt, multiplexed);
          })(request);
        }
      }

      return Response.notFound('Not found');
    };
  }

  void _setupCustomMessageHandling(
      MultiplexedWebSocketChannel channel, String context,
      [ProjectDatabase? db]) {
    final agentSession = _AgentSession(channel, db);

    // The subscription will be automatically cancelled when the channel is closed
    // (connection dropped) as the stream will send a done event.
    channel.onCustomMessage.listen((msg) {
      developer.log('Server ($context): Received custom message: $msg');
      if (msg['type'] == 'PING') {
        channel.sendCustomMessage({
          'type': 'PONG',
          'payload': msg['payload'],
        });
      } else if (msg['type'] == 'start_chat' ||
          msg['type'] == 'approval_response') {
        agentSession.handleMessage(msg);
      }
    });
  }
}

class _AgentSession {
  final MultiplexedWebSocketChannel channel;
  final ProjectDatabase? db;
  Completer<List<PendingToolCall>?>? _approvalCompleter;
  List<PendingToolCall>? _currentPendingCalls;

  _AgentSession(this.channel, this.db);

  void handleMessage(Map<String, dynamic> msg) {
    if (msg['type'] == 'start_chat') {
      _startChat(msg);
    } else if (msg['type'] == 'approval_response') {
      _handleApproval(msg);
    }
  }

  void _handleApproval(Map<String, dynamic> data) {
    developer.log('✅ Received approval response', name: 'AgentSession');
    final approvedIds = (data['approvedIds'] as List?)?.cast<String>();

    if (_approvalCompleter != null && !_approvalCompleter!.isCompleted) {
      if (approvedIds == null) {
        _approvalCompleter!.complete(null);
      } else {
        // Filter pending calls
        final pending = _currentPendingCalls ?? [];
        final approved =
            pending.where((c) => approvedIds.contains(c.id)).toList();
        _approvalCompleter!.complete(approved);
      }
    }
  }

  Future<void> _startChat(Map<String, dynamic> data) async {
    developer.log('🚀 Starting agent loop', name: 'AgentSession');
    try {
      final config = data['config'] as Map<String, dynamic>;
      final sessionId = data['sessionId'] as String?;

      List<ChatMessage> conversation;
      if (data.containsKey('conversation')) {
        final conversationJson =
            (data['conversation'] as List).cast<Map<String, dynamic>>();
        conversation = conversationJson.map((j) => j.toChatMessage()).toList();
      } else {
        if (sessionId == null || db == null) {
          throw Exception(
              'Session ID and Database required when conversation is not provided');
        }
        final dbMessages = await db!.messageDao.getMessagesBySession(sessionId);
        conversation = dbMessages.map((m) => m.toChatMessage()).toList();
      }

      final apiKey = config['apiKey'] as String;
      final providerType = config['provider'] as String;
      final model = config['model'] as String;
      final baseUrl = config['baseUrl'] as String?;

      final provider =
          await _createProvider(providerType, apiKey, model, baseUrl);

      await runAgentLoop(
        llmStream: (conv, tools) {
          return provider.chatStream(conv, tools: tools);
        },
        tools: shellTools,
        conversation: conversation,
        requestApproval: (pendingCalls) {
          _currentPendingCalls = pendingCalls;

          channel.sendCustomMessage({
            'type': 'request_approval',
            'tools': pendingCalls
                .map((c) =>
                    {'id': c.id, 'name': c.name, 'arguments': c.arguments})
                .toList()
          });

          final completer = Completer<List<PendingToolCall>?>();
          _approvalCompleter = completer;
          return completer.future;
        },
        executeToolCall: (toolCall) async {
          final argumentsJson = toolCall.function.arguments;
          final params = argumentsJson.isNotEmpty
              ? Map<String, dynamic>.from(jsonDecode(argumentsJson))
              : <String, dynamic>{};

          if (toolCall.function.name == kExecuteShellCommand) {
            final command = params['command'] as String;
            final result = await _executeLocalCommand(command);
            return jsonEncode(result);
          } else if (toolCall.function.name == kFetch) {
            return jsonEncode({'error': 'Fetch not implemented on server yet'});
          }

          return jsonEncode({'error': 'Unknown tool'});
        },
        onTextDelta: (delta) {
          channel.sendCustomMessage({'type': 'text_delta', 'content': delta});
        },
        onAssistantMessage: (message, {String? messageId}) async {
          String? id;
          if (db != null && sessionId != null) {
            id = db!.messageDao.generateMessageId();
            // Determine if this is a tool use message or a text message
            final messageType = message.messageType;
            if (messageType is ToolUseMessage) {
              await db!.messageDao.insertMessage(
                message.toMessageCompanion(sessionId: sessionId, id: id),
              );
            } else {
              await db!.messageDao.insertMessageWithId(
                id: id,
                sessionId: sessionId,
                userId: 'ai',
                userName: 'Ops Agent',
                content: message.content,
              );
            }
          }

          channel.sendCustomMessage({
            'type': 'assistant_message',
            'message': message.toJson(),
            if (id != null) 'id': id,
          });
        },
        onToolResultMessage: (message, {String? messageId}) async {
          String? id;
          if (db != null && sessionId != null) {
            id = db!.messageDao.generateMessageId();
            await db!.messageDao.insertMessage(
              message.toMessageCompanion(sessionId: sessionId, id: id),
            );
          }

          channel.sendCustomMessage({
            'type': 'tool_result_message',
            'message': message.toJson(),
            if (id != null) 'id': id,
          });
        },
      );

      channel.sendCustomMessage({'type': 'complete'});
    } catch (e) {
      developer.log('Error in agent loop: $e', name: 'AgentSession');
      channel.sendCustomMessage({'type': 'error', 'message': e.toString()});
    }
  }

  Future<ChatCapability> _createProvider(
      String type, String apiKey, String model, String? baseUrl) async {
    if (type == 'openai') {
      final builder = ai().openai().apiKey(apiKey).model(model);
      if (baseUrl != null) builder.baseUrl(baseUrl);
      return await builder.build();
    } else if (type == 'anthropic') {
      final builder = ai().anthropic().apiKey(apiKey).model(model);
      if (baseUrl != null) builder.baseUrl(baseUrl);
      return await builder.build();
    }
    // Add other providers as needed
    throw Exception('Unsupported provider: $type');
  }

  Future<Map<String, dynamic>> _executeLocalCommand(String command) async {
    try {
      final result = await Process.run('bash', ['-c', command]);
      return {
        'stdout': result.stdout,
        'stderr': result.stderr,
        'exitCode': result.exitCode,
      };
    } catch (e) {
      return {
        'stdout': '',
        'stderr': e.toString(),
        'exitCode': -1,
      };
    }
  }
}
