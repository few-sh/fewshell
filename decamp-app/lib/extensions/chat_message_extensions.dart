import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:llm_dart/llm_dart.dart';
import '../database/database.dart';
import '../database/tables/messages_table.dart';
import '../utils/id_generator.dart';

/// Extensions for ChatMessage to support conversion to database entities
extension ChatMessageToDB on ChatMessage {
  /// Convert ChatMessage to database companion for insertion
  MessageEntityCompanion toMessageCompanion({
    required String sessionId,
    String? id,
  }) {
    final now = DateTime.now();
    final messageId = id ?? IdGenerator.messageId();

    // Determine message kind and type-specific data
    final MessageKind kind;
    final String? imageUrlValue;
    final String? toolCallsJsonValue;
    final String? toolResultsJsonValue;

    switch (messageType) {
      case TextMessage():
        kind = MessageKind.text;
        imageUrlValue = null;
        toolCallsJsonValue = null;
        toolResultsJsonValue = null;

      case ImageUrlMessage(:final url):
        kind = MessageKind.imageUrl;
        imageUrlValue = url;
        toolCallsJsonValue = null;
        toolResultsJsonValue = null;

      case ToolUseMessage(:final toolCalls):
        kind = MessageKind.toolUse;
        imageUrlValue = null;
        toolCallsJsonValue = jsonEncode(
          toolCalls.map((tc) => tc.toJson()).toList(),
        );
        toolResultsJsonValue = null;

      case ToolResultMessage(:final results):
        kind = MessageKind.toolResult;
        imageUrlValue = null;
        toolCallsJsonValue = null;
        toolResultsJsonValue = jsonEncode(
          results.map((tc) => tc.toJson()).toList(),
        );

      default:
        // ImageMessage and FileMessage would need special handling
        // For now, treat as text
        kind = MessageKind.text;
        imageUrlValue = null;
        toolCallsJsonValue = null;
        toolResultsJsonValue = null;
    }

    return MessageEntityCompanion(
      id: Value(messageId),
      sessionId: Value(sessionId),
      userId: Value(_userIdFromRole(role)),
      userName: Value(_userNameFromRole(role)),
      content: Value(content),
      timestamp: Value(now),
      createdAt: Value(now),
      messageKind: Value(kind),
      imageUrl: Value(imageUrlValue),
      toolCallsJson: Value(toolCallsJsonValue),
      toolResultsJson: Value(toolResultsJsonValue),
    );
  }

  String _userIdFromRole(ChatRole role) {
    return switch (role) {
      ChatRole.user => 'user',
      ChatRole.assistant => 'ai',
      ChatRole.system => 'system',
    };
  }

  String _userNameFromRole(ChatRole role) {
    return switch (role) {
      ChatRole.user => 'You',
      ChatRole.assistant => 'Ops Agent',
      ChatRole.system => 'System',
    };
  }
}

/// Extensions for MessageEntity to support conversion to ChatMessage
extension MessageEntityToChat on MessageEntity {
  /// Helper to get tool calls from JSON
  List<ToolCall>? get toolCalls {
    if (messageKind != MessageKind.toolUse || toolCallsJson == null)
      return null;
    final json = jsonDecode(toolCallsJson!) as List;
    return json
        .map((e) => ToolCall.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Helper to get tool results from JSON
  List<ToolCall>? get toolResults {
    if (messageKind != MessageKind.toolResult || toolResultsJson == null)
      return null;
    final json = jsonDecode(toolResultsJson!) as List;
    return json
        .map((e) => ToolCall.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Convert MessageEntity to ChatMessage
  ChatMessage toChatMessage() {
    final role = _roleFromUserId(userId);

    return switch (messageKind) {
      MessageKind.toolUse => ChatMessage.toolUse(
        toolCalls: toolCalls!,
        content: content,
      ),
      MessageKind.toolResult => ChatMessage.toolResult(
        results: toolResults!,
        content: content,
      ),
      MessageKind.imageUrl => ChatMessage.imageUrl(
        role: role,
        url: imageUrl!,
        content: content,
      ),
      MessageKind.text =>
        role == ChatRole.user
            ? ChatMessage.user(content)
            : ChatMessage.assistant(content),
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
}
