import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

/// Represents a message in a chat session.
/// Can be from user or AI assistant.
@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    required String sessionId,
    required String userId,
    required String userName,
    required String content,
    required DateTime timestamp,
    required DateTime createdAt,
    // Optional fields for rich content
    String? imageUrl,
    Map<String, dynamic>? metadata,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}
