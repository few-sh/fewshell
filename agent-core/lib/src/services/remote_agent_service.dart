import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:agent_core/agent_core.dart';
import 'package:llm_dart/llm_dart.dart';

/// Runs the agent loop remotely on the server using the existing sync channel
Future<AgentLoopResult> runRemoteAgentLoop({
  required MultiplexedWebSocketChannel channel,
  required Map<String, dynamic> config,
  required String sessionId,
  required MessageEntity triggerMessage,
  required ApprovalFunction requestApproval,
  MessageCallback? onAssistantMessage,
  MessageCallback? onToolResultMessage,
}) async {
  developer.log(
      'Starting remote agent loop with sessionId: $sessionId triggerMessage: ${triggerMessage.toJsonString()}',
      name: 'RemoteAgentService');

  final completer = Completer<AgentLoopResult>();

  // Listen for messages on the custom channel
  final subscription = channel.onCustomMessage.listen(
    (data) async {
      try {
        final type = data['type'] as String;

        if (type == 'request_approval') {
          final toolsJson =
              (data['tools'] as List).cast<Map<String, dynamic>>();
          final pendingCalls = toolsJson
              .map((j) => PendingToolCall(
                  id: j['id'],
                  name: j['name'],
                  arguments: j['arguments'],
                  originalToolCall: ToolCall(
                      id: j['id'],
                      callType: 'function',
                      function: FunctionCall(
                          name: j['name'],
                          arguments: jsonEncode(j['arguments'])))))
              .toList();

          final approved = await requestApproval(pendingCalls);

          channel.sendCustomMessage({
            'type': 'approval_response',
            'approvedIds': approved?.map((c) => c.id).toList()
          });
        } else if (type == 'complete') {
          if (!completer.isCompleted) {
            completer.complete(const AgentLoopCompleted());
          }
        } else if (type == 'error') {
          if (!completer.isCompleted) {
            completer.complete(AgentLoopError(data['message']));
          }
        }
      } catch (e) {
        developer.log('Error handling remote message: $e',
            name: 'RemoteAgentService');
        if (!completer.isCompleted) {
          completer.complete(AgentLoopError(e.toString()));
        }
      }
    },
    onError: (e) {
      if (!completer.isCompleted) {
        completer.complete(AgentLoopError(e.toString()));
      }
    },
  );

  // Start chat
  channel.sendCustomMessage({
    'type': 'start_chat',
    'config': config,
    'sessionId': sessionId,
    'triggerMessage': triggerMessage.toJson(),
  });

  try {
    return await completer.future;
  } finally {
    await subscription.cancel();
  }
}
