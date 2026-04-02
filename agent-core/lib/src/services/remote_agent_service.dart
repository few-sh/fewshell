import 'dart:async';
import 'package:logging/logging.dart';

import 'package:agent_core/agent_core.dart';

final _log = Logger('RemoteAgentService');

/// Runs the agent loop remotely on the server using the existing sync channel
Future<AgentLoopResult> runRemoteAgentLoop({
  required MultiplexedWebSocketChannel channel,
  required Map<String, dynamic> config,
  required String sessionId,
  required MessageEntity triggerMessage,
  required ApprovalFunction requestApproval,
}) async {
  _log.info(
      'Starting remote agent loop with sessionId: $sessionId triggerMessage: ${triggerMessage.toJsonString()}');

  final completer = Completer<AgentLoopResult>();

  // Listen for messages on the custom channel
  Future<void> handleMessage(Map<String, dynamic> data) async {
    try {
      final type = data['type'] as String;

      if (type == 'request_approval') {
        final toolsJson = (data['tools'] as List).cast<Map<String, dynamic>>();
        final msgSessionId = data['sessionId'] as String;

        // Validate that this approval request is for the session this loop is
        // handling. This is important because even if the app's active session
        // changes while an approval is pending, we only process requests that
        // belong to our session. This is enforced on the client side via
        // session validation in the requestApproval callback, which returns null
        // if the user has switched sessions (no response sent to server).
        if (msgSessionId != sessionId) {
          _log.warning(
              'Received approval request for session $msgSessionId but this loop is for session $sessionId. Ignoring.');
          return;
        }

        final pendingCalls =
            toolsJson.map(PendingToolCall.fromApprovalRequestJson).toList();

        final approved = await requestApproval(pendingCalls);

        if (approved == null) {
          // null = don't send a response (e.g., app was on wrong session)
          _log.info(
            'Approval request handled without response (approved was null)',
          );
        } else if (approved.isEmpty) {
          // empty list = user cancelled/rejected all tools
          channel.sendCustomMessage({
            'type': 'approval_response',
            'approvedCalls': [], // empty list signals user cancellation
            'sessionId': sessionId,
          });
        } else {
          // non-empty list = tools were approved
          channel.sendCustomMessage({
            'type': 'approval_response',
            'approvedCalls':
                approved.map((c) => c.toApprovalResponseJson()).toList(),
            'sessionId': sessionId,
          });
        }
      } else if (type == 'complete') {
        if (!completer.isCompleted) {
          completer.complete(const AgentLoopCompleted());
        }
      } else if (type == 'cancelled') {
        if (!completer.isCompleted) {
          completer.complete(const AgentLoopCancelled());
        }
      } else if (type == 'error') {
        if (!completer.isCompleted) {
          completer.complete(
              AgentLoopError(data['message'], messageId: data['message_id']));
        }
      }
    } catch (e, st) {
      _log.severe('Error handling remote message', e, st);
      if (!completer.isCompleted) {
        completer.complete(AgentLoopError(e.toString()));
      }
    }
  }

  channel.registerCustomHandler(handleMessage);

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
    channel.unregisterCustomHandler(handleMessage);
  }
}

/// Sends a `summarize` request to the server and waits for the result.
///
/// Returns `true` if the server performed summarization, `false` otherwise.
Future<bool> runRemoteSummarize({
  required MultiplexedWebSocketChannel channel,
  required Map<String, dynamic> config,
  required String sessionId,
  required bool hideMessages,
}) async {
  _log.info('Requesting remote summarization for session $sessionId');

  final completer = Completer<bool>();

  Future<void> handleMessage(Map<String, dynamic> data) async {
    try {
      final type = data['type'] as String;

      if (type == 'summarize_complete') {
        if (!completer.isCompleted) {
          completer.complete(data['performed'] as bool? ?? true);
        }
      } else if (type == 'summarize_error') {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(data['message'] ?? 'Remote summarization failed'),
          );
        }
      }
    } catch (e, st) {
      _log.severe('Error handling remote summarize message', e, st);
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }
  }

  channel.registerCustomHandler(handleMessage);

  channel.sendCustomMessage({
    'type': 'summarize',
    'config': config,
    'sessionId': sessionId,
    'hideMessages': hideMessages,
  });

  try {
    return await completer.future;
  } finally {
    channel.unregisterCustomHandler(handleMessage);
  }
}
