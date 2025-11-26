import 'dart:convert';

import 'package:llm_dart/llm_dart.dart';

import 'models/message.dart';

// Re-export MessageKind for backwards compatibility
export 'models/message.dart' show MessageKind;

/// User ID constants
const String kUserUserId = 'user';
const String kUserUserName = 'You';
const String kAiUserId = 'ai';
const String kAiUserName = 'Ops Agent';
const String kSystemUserId = 'system';
const String kSystemUserName = 'System';
const String kToolUserId = 'tool';
const String kToolUserName = 'Tool';

/// Converts a ChatMessage to a serializable map for storage/transport
///
/// The map structure matches the database schema used by both client and server
Map<String, dynamic> chatMessageToMap(
  ChatMessage message, {
  required String id,
  required String sessionId,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;

  // Determine message kind and type-specific data
  final MessageKind kind;
  String? imageUrl;
  List<Map<String, dynamic>>? toolCallsJson;
  List<Map<String, dynamic>>? toolResultsJson;

  switch (message.messageType) {
    case TextMessage():
      kind = MessageKind.text;

    case ImageUrlMessage(:final url):
      kind = MessageKind.imageUrl;
      imageUrl = url;

    case ToolUseMessage(:final toolCalls):
      kind = MessageKind.toolUse;
      toolCallsJson = toolCalls.map(toolCallToMap).toList();

    case ToolResultMessage(:final results):
      kind = MessageKind.toolResult;
      toolResultsJson = results.map(toolCallToMap).toList();

    default:
      // ImageMessage and FileMessage would need special handling
      // For now, treat as text
      kind = MessageKind.text;
  }

  return {
    'id': id,
    'session_id': sessionId,
    'user_id': _userIdFromRole(message.role),
    'user_name': _userNameFromRole(message.role),
    'content': message.content,
    'created_at': now,
    'message_kind': kind.index,
    'image_url': imageUrl,
    'tool_calls_json': toolCallsJson != null ? jsonEncode(toolCallsJson) : null,
    'tool_results_json':
        toolResultsJson != null ? jsonEncode(toolResultsJson) : null,
  };
}

/// Converts a map (from database/JSON) to a ChatMessage
/// Handles both snake_case (from old database) and camelCase (from server API)
ChatMessage mapToChatMessage(Map<String, dynamic> map) {
  // Support both snake_case and camelCase keys
  final userId = (map['user_id'] ?? map['userId']) as String;
  final content = map['content'] as String;
  final kindIndex = (map['message_kind'] ?? map['messageKind']) as int;
  final kind = MessageKind.values[kindIndex];
  final role = _roleFromUserId(userId);

  switch (kind) {
    case MessageKind.text:
      return role == ChatRole.user
          ? ChatMessage.user(content)
          : ChatMessage.assistant(content);

    case MessageKind.imageUrl:
      final imageUrl = (map['image_url'] ?? map['imageUrl']) as String;
      return ChatMessage.imageUrl(role: role, url: imageUrl, content: content);

    case MessageKind.toolUse:
      final toolCallsJson =
          (map['tool_calls_json'] ?? map['toolCallsJson']) as String?;
      final toolCalls =
          toolCallsJson != null ? _parseToolCalls(toolCallsJson) : <ToolCall>[];
      return ChatMessage.toolUse(toolCalls: toolCalls, content: content);

    case MessageKind.toolResult:
      final toolResultsJson =
          (map['tool_results_json'] ?? map['toolResultsJson']) as String?;
      final results = toolResultsJson != null
          ? _parseToolCalls(toolResultsJson)
          : <ToolCall>[];
      return ChatMessage.toolResult(results: results, content: content);
  }
}

/// Converts a ToolCall to a serializable map
Map<String, dynamic> toolCallToMap(ToolCall tc) {
  return {
    'id': tc.id,
    'type': tc.callType,
    'function': {
      'name': tc.function.name,
      'arguments': tc.function.arguments,
    },
  };
}

/// Parses a JSON string into a list of ToolCalls
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

String _userIdFromRole(ChatRole role) {
  return switch (role) {
    ChatRole.user => kUserUserId,
    ChatRole.assistant => kAiUserId,
    ChatRole.system => kSystemUserId,
  };
}

String _userNameFromRole(ChatRole role) {
  return switch (role) {
    ChatRole.user => kUserUserName,
    ChatRole.assistant => kAiUserName,
    ChatRole.system => kSystemUserName,
  };
}

ChatRole _roleFromUserId(String userId) {
  return switch (userId) {
    'user' => ChatRole.user,
    'ai' || 'assistant' => ChatRole.assistant,
    'system' => ChatRole.system,
    'tool' => ChatRole.assistant, // Tool messages treated as assistant
    _ => ChatRole.user,
  };
}
