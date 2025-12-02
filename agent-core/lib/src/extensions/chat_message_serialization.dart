import 'dart:convert';
import 'package:llm_dart/llm_dart.dart';

extension ChatMessageSerialization on ChatMessage {
  Map<String, dynamic> toJson() {
    final type = switch (messageType) {
      TextMessage() => 'text',
      ImageMessage() => 'image',
      FileMessage() => 'file',
      ImageUrlMessage() => 'image_url',
      ToolUseMessage() => 'tool_use',
      ToolResultMessage() => 'tool_result',
    };

    final data = <String, dynamic>{
      'role': role.name,
      'type': type,
      'content': content,
      if (name != null) 'name': name,
      if (extensions.isNotEmpty) 'extensions': extensions,
    };

    switch (messageType) {
      case ImageMessage(mime: final mime, data: final bytes):
        data['mime'] = mime.mimeType;
        data['data'] = base64Encode(bytes);
      case FileMessage(mime: final mime, data: final bytes):
        data['mime'] = mime.mimeType;
        data['data'] = base64Encode(bytes);
      case ImageUrlMessage(url: final url):
        data['url'] = url;
      case ToolUseMessage(toolCalls: final calls):
        data['tool_calls'] = calls.map((c) => c.toJson()).toList();
      case ToolResultMessage(results: final results):
        data['tool_results'] = results.map((r) => r.toJson()).toList();
      case TextMessage():
        break;
    }

    return data;
  }
}

extension ChatMessageDeserialization on Map<String, dynamic> {
  ChatMessage toChatMessage() {
    final roleName = this['role'] as String?;
    final role = ChatRole.values.firstWhere(
      (e) => e.name == roleName,
      orElse: () => ChatRole.user,
    );

    final type = this['type'] as String? ?? 'text';
    final content = this['content'] as String? ?? '';
    final name = this['name'] as String?;
    final extensions = this['extensions'] as Map<String, dynamic>? ?? {};

    MessageType messageType;
    switch (type) {
      case 'text':
        messageType = const TextMessage();
      case 'image':
        final mimeStr = this['mime'] as String? ?? 'image/jpeg';
        final mime = ImageMime.values.firstWhere(
          (e) => e.mimeType == mimeStr,
          orElse: () => ImageMime.jpeg,
        );
        final dataStr = this['data'] as String?;
        final data = dataStr != null ? base64Decode(dataStr) : <int>[];
        messageType = ImageMessage(mime, data);
      case 'file':
        final mimeStr = this['mime'] as String? ?? 'application/octet-stream';
        final mime = FileMime(mimeStr);
        final dataStr = this['data'] as String?;
        final data = dataStr != null ? base64Decode(dataStr) : <int>[];
        messageType = FileMessage(mime, data);
      case 'image_url':
        messageType = ImageUrlMessage(this['url'] as String? ?? '');
      case 'tool_use':
        final callsList = this['tool_calls'] as List?;
        final calls = callsList
                ?.map((c) => ToolCall.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [];
        messageType = ToolUseMessage(calls);
      case 'tool_result':
        final resultsList = this['tool_results'] as List?;
        final results = resultsList
                ?.map((r) => ToolCall.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [];
        messageType = ToolResultMessage(results);
      default:
        messageType = const TextMessage();
    }

    return ChatMessage(
      role: role,
      messageType: messageType,
      content: content,
      name: name,
      extensions: extensions,
    );
  }
}
