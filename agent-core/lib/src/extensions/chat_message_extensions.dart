import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:llm_dart/llm_dart.dart';

import '../database/database.dart';
import '../database/tables/messages_table.dart';
import '../services/shell_tools_provider.dart' show kExecuteShellCommand;
import '../utils/ansi.dart';
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
      MessageKind.toolResult => _buildToolResultMessages(),
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
          ChatMessage.user(
              summary ?? '[Unexpected Error: No summary available]'),
        ],
      MessageKind.notification => [],
    };
  }

  /// Build tool result messages, substituting summarized content where available.
  List<ChatMessage> _buildToolResultMessages() {
    final results = toolResultsJson ?? [];

    // Parse the summary map if present: {toolCallId: summarizedContent}.
    final summaryMap = _parseSummaryMap();

    // Replace oversized tool results with their summarized content,
    // and strip ANSI escape sequences from shell command stdout/stderr
    // (raw bytes are kept in the DB for terminal-style UI rendering, but
    // would just waste tokens / confuse the LLM).
    final effectiveResults = results.map((toolResult) {
      final summarized = summaryMap?[toolResult.id];
      final effectiveArgs = summarized ??
          _stripAnsiFromToolResult(
            toolResult.function.name,
            toolResult.function.arguments,
          );
      if (identical(effectiveArgs, toolResult.function.arguments)) {
        return toolResult;
      }
      // Swap in the cleaned content, preserving the tool call metadata.
      return ToolCall(
        id: toolResult.id,
        callType: toolResult.callType,
        function: FunctionCall(
          name: toolResult.function.name,
          arguments: effectiveArgs,
        ),
      );
    }).toList();

    return [
      ChatMessage.toolUse(
        toolCalls: toolCallsJson ?? [],
        content: content,
      ),
      ChatMessage.toolResult(
        results: effectiveResults,
        content: content,
      ),
    ];
  }

  /// Decode the summary field as a {toolCallId: summarizedContent} map.
  Map<String, String>? _parseSummaryMap() {
    if (summary == null) return null;
    try {
      final decoded = jsonDecode(summary!);
      if (decoded is! Map) return null;
      return Map<String, String>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  /// For shell tool results, strip ANSI escape sequences from
  /// `stdout`/`stderr` in the JSON payload. Returns the original string
  /// unchanged if the tool isn't a shell command, the payload isn't valid
  /// JSON, or there are no escape sequences to strip.
  String _stripAnsiFromToolResult(String toolName, String argumentsJson) {
    if (toolName != kExecuteShellCommand) return argumentsJson;
    try {
      final decoded = jsonDecode(argumentsJson);
      if (decoded is! Map<String, dynamic>) return argumentsJson;
      var changed = false;
      final cleaned = Map<String, dynamic>.from(decoded);
      for (final field in const ['stdout', 'stderr']) {
        final value = cleaned[field];
        if (value is String) {
          final stripped = stripAnsi(value);
          if (!identical(stripped, value) && stripped != value) {
            cleaned[field] = stripped;
            changed = true;
          }
        }
      }
      return changed ? jsonEncode(cleaned) : argumentsJson;
    } catch (_) {
      return argumentsJson;
    }
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
