import 'package:llm_dart/llm_dart.dart';

/// Extensions for ChatMessage to support serialization/deserialization
/// This allows us to store and reconstruct complete ChatMessage objects
/// including tool use and tool results without modifying llm_dart package
extension ChatMessageSerialization on ChatMessage {
  /// Convert ChatMessage to JSON for storage
  /// For tool messages, we store the tool call data separately so we can
  /// recreate them using llm_dart's factory methods
  Map<String, dynamic> toStorageJson() {
    final json = <String, dynamic>{'role': role.name, 'content': content};

    if (name != null) {
      json['name'] = name;
    }

    if (extensions.isNotEmpty) {
      json['extensions'] = extensions;
    }

    // Serialize messageType - for tool messages, save the ToolCall data
    switch (messageType) {
      case TextMessage():
        json['messageType'] = 'text';
      case ImageMessage(:final mime, :final data):
        json['messageType'] = 'image';
        json['imageMime'] = mime.name;
        json['imageData'] = data;
      case FileMessage(:final mime, :final data):
        json['messageType'] = 'file';
        json['fileMime'] = mime.mimeType;
        json['fileData'] = data;
      case ImageUrlMessage(:final url):
        json['messageType'] = 'imageUrl';
        json['imageUrl'] = url;
      case ToolUseMessage(:final toolCalls):
        json['messageType'] = 'toolUse';
        // Store the raw ToolCall JSON so we can recreate using factory methods
        json['toolCalls'] = toolCalls.map((tc) => tc.toJson()).toList();
      case ToolResultMessage(:final results):
        json['messageType'] = 'toolResult';
        // Store the raw ToolCall JSON
        json['toolResults'] = results.map((tc) => tc.toJson()).toList();
    }

    return json;
  }
}

/// Helper class to deserialize ChatMessage from storage JSON
class ChatMessageStorage {
  /// Create ChatMessage from stored JSON
  /// Uses llm_dart's factory methods to ensure compatibility
  static ChatMessage fromStorageJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String;
    final role = ChatRole.values.firstWhere((r) => r.name == roleStr);
    final content = json['content'] as String? ?? '';
    final name = json['name'] as String?;

    final messageTypeStr = json['messageType'] as String?;

    // For tool messages, use llm_dart's factory methods to ensure proper structure
    switch (messageTypeStr) {
      case 'toolUse':
        final toolCallsJson = json['toolCalls'] as List;
        final toolCalls = toolCallsJson
            .map((tc) => ToolCall.fromJson(tc as Map<String, dynamic>))
            .toList();
        // Use the factory method to ensure proper structure
        return ChatMessage.toolUse(toolCalls: toolCalls, content: content);

      case 'toolResult':
        final resultsJson = json['toolResults'] as List;
        final results = resultsJson
            .map((tc) => ToolCall.fromJson(tc as Map<String, dynamic>))
            .toList();
        // Use the factory method to ensure proper structure
        return ChatMessage.toolResult(results: results, content: content);

      case 'image':
        final mimeStr = json['imageMime'] as String;
        final mime = ImageMime.values.firstWhere((m) => m.name == mimeStr);
        final data = (json['imageData'] as List).cast<int>();
        return ChatMessage.image(
          role: role,
          mime: mime,
          data: data,
          content: content,
        );

      case 'file':
        final mimeStr = json['fileMime'] as String;
        final mime = FileMime(mimeStr);
        final data = (json['fileData'] as List).cast<int>();
        return ChatMessage.file(
          role: role,
          mime: mime,
          data: data,
          content: content,
        );

      case 'imageUrl':
        final url = json['imageUrl'] as String;
        return ChatMessage.imageUrl(role: role, url: url, content: content);

      default:
        // Text message - use appropriate factory based on role
        if (role == ChatRole.user) {
          return ChatMessage.user(content);
        } else if (role == ChatRole.assistant) {
          return ChatMessage.assistant(content);
        } else if (role == ChatRole.system) {
          return ChatMessage.system(content, name: name);
        } else {
          // Fallback
          return ChatMessage.user(content);
        }
    }
  }
}
