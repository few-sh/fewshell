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
    String? userName,
    ChatMessage? toolCallMessage,
  }) {
    final now = DateTime.now();
    final messageId = id ?? IdGenerator.messageId();

    // Determine message kind and type-specific data
    final MessageKind kind;
    final String? imageUrlValue;
    final List<ToolCall>? toolCallsValue;
    final List<ToolCall>? toolResultsValue;

    switch (messageType) {
      case TextMessage():
        kind = MessageKind.text;
        imageUrlValue = null;
        toolCallsValue = null;
        toolResultsValue = null;

      case ImageUrlMessage(:final url):
        kind = MessageKind.imageUrl;
        imageUrlValue = url;
        toolCallsValue = null;
        toolResultsValue = null;

      case ToolUseMessage(:final toolCalls):
        kind = MessageKind.toolUse;
        imageUrlValue = null;
        toolCallsValue = toolCalls;
        toolResultsValue = null;

      case ToolResultMessage(:final results):
        kind = MessageKind.toolResult;
        imageUrlValue = null;
        toolCallsValue = switch (toolCallMessage?.messageType) {
          ToolUseMessage(:final toolCalls) => toolCalls,
          _ => null,
        };
        toolResultsValue = results;

      default:
        // ImageMessage and FileMessage would need special handling
        // For now, treat as text
        kind = MessageKind.text;
        imageUrlValue = null;
        toolCallsValue = null;
        toolResultsValue = null;
    }

    return MessageEntityCompanion(
      id: Value(messageId),
      sessionId: Value(sessionId),
      userId: Value(_userIdFromRole(role)),
      userName: Value(userName ?? _userNameFromRole(role)),
      content: Value(content),
      timestamp: Value(now),
      createdAt: Value(now),
      messageKind: Value(kind),
      imageUrl: Value(imageUrlValue),
      toolCallsJson: Value(toolCallsValue),
      toolResultsJson: Value(toolResultsValue),
      isVisibleToLlm: Value(true),
    );
  }

  /// Convert ChatMessage to database entity
  MessageEntity toMessageEntity({
    required String sessionId,
    String? id,
    String? userName,
    ChatMessage? toolCallMessage,
    DateTime? timestamp,
    isStreaming = false,
  }) {
    final now = timestamp ?? DateTime.now();
    final messageId = id ?? IdGenerator.messageId();

    // Determine message kind and type-specific data
    final MessageKind kind;
    final String? imageUrlValue;
    final List<ToolCall>? toolCallsValue;
    final List<ToolCall>? toolResultsValue;

    switch (messageType) {
      case TextMessage():
        kind = MessageKind.text;
        imageUrlValue = null;
        toolCallsValue = null;
        toolResultsValue = null;

      case ImageUrlMessage(:final url):
        kind = MessageKind.imageUrl;
        imageUrlValue = url;
        toolCallsValue = null;
        toolResultsValue = null;

      case ToolUseMessage(:final toolCalls):
        kind = MessageKind.toolUse;
        imageUrlValue = null;
        toolCallsValue = toolCalls;
        toolResultsValue = null;

      case ToolResultMessage(:final results):
        kind = MessageKind.toolResult;
        imageUrlValue = null;
        toolCallsValue = switch (toolCallMessage?.messageType) {
          ToolUseMessage(:final toolCalls) => toolCalls,
          _ => null,
        };
        toolResultsValue = results;

      default:
        // ImageMessage and FileMessage would need special handling
        // For now, treat as text
        kind = MessageKind.text;
        imageUrlValue = null;
        toolCallsValue = null;
        toolResultsValue = null;
    }

    return MessageEntity(
      id: messageId,
      sessionId: sessionId,
      userId: _userIdFromRole(role),
      userName: userName ?? _userNameFromRole(role),
      content: content,
      timestamp: now,
      createdAt: now,
      editedAt: null,
      isStreaming: isStreaming,
      isVisibleToLlm: true,
      messageKind: kind,
      imageUrl: imageUrlValue,
      toolCallsJson: toolCallsValue,
      toolResultsJson: toolResultsValue,
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
  /// Convert MessageEntity to ChatMessage
  List<ChatMessage> toChatMessage() {
    final role = _roleFromUserId(userId);

    return switch (messageKind) {
      MessageKind.toolUse => [
          ChatMessage.toolUse(
            toolCalls: toolCallsJson ?? [],
            content: content,
          ),
          ChatMessage.toolResult(
            results:
                toolCallsJson ?? // Empty results for tool use - this is not a typo!
                    [],
            content: content,
          )
        ],
      MessageKind.toolResult => [
          ChatMessage.toolUse(
            toolCalls: toolCallsJson ?? [],
            content: content,
          ),
          ChatMessage.toolResult(
            results: toolResultsJson ?? [],
            content: content,
          )
        ],
      MessageKind.imageUrl => [
          ChatMessage.imageUrl(
            role: role,
            url: imageUrl!,
            content: content,
          )
        ],
      MessageKind.text => role == ChatRole.user
          ? [ChatMessage.user(content)]
          : [ChatMessage.assistant(content)],
      MessageKind.conversationSummary => [
          // Summaries are injected as user messages so the LLM treats them
          // as context it should build upon (handoff from previous model).
          ChatMessage.user(content),
        ],
      MessageKind.toolResultSummary => [
          ChatMessage.user(content),
        ],
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
