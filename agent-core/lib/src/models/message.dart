/// Message kind discriminator for sum type representation.
/// Matches the client database schema.
enum MessageKind {
  text,
  imageUrl,
  toolUse,
  toolResult,
}

/// A message in a chat session.
///
/// This model is shared between client and server for consistency.
/// The messageKind field discriminates the type of content.
class Message {
  /// Unique identifier
  final String id;

  /// Session this message belongs to
  final String sessionId;

  /// User ID ('user', 'ai', 'system', 'tool')
  final String userId;

  /// Display name for the user
  final String userName;

  /// Message content/text
  final String content;

  /// When the message was created
  final DateTime createdAt;

  /// When the message was edited (null if never edited)
  final DateTime? editedAt;

  /// Discriminator: what kind of message is this?
  final MessageKind messageKind;

  /// Image URL (only for imageUrl kind)
  final String? imageUrl;

  /// Tool calls JSON (only for toolUse kind)
  final String? toolCallsJson;

  /// Tool results JSON (only for toolResult kind)
  final String? toolResultsJson;

  const Message({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
    this.editedAt,
    this.messageKind = MessageKind.text,
    this.imageUrl,
    this.toolCallsJson,
    this.toolResultsJson,
  });

  Message copyWith({
    String? id,
    String? sessionId,
    String? userId,
    String? userName,
    String? content,
    DateTime? createdAt,
    DateTime? editedAt,
    MessageKind? messageKind,
    String? imageUrl,
    String? toolCallsJson,
    String? toolResultsJson,
  }) {
    return Message(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      messageKind: messageKind ?? this.messageKind,
      imageUrl: imageUrl ?? this.imageUrl,
      toolCallsJson: toolCallsJson ?? this.toolCallsJson,
      toolResultsJson: toolResultsJson ?? this.toolResultsJson,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'userId': userId,
        'userName': userName,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'editedAt': editedAt?.toIso8601String(),
        'messageKind': messageKind.index,
        'imageUrl': imageUrl,
        'toolCallsJson': toolCallsJson,
        'toolResultsJson': toolResultsJson,
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        sessionId: json['sessionId'] as String,
        userId: json['userId'] as String,
        userName: json['userName'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        editedAt: json['editedAt'] != null
            ? DateTime.parse(json['editedAt'] as String)
            : null,
        messageKind: MessageKind.values[json['messageKind'] as int? ?? 0],
        imageUrl: json['imageUrl'] as String?,
        toolCallsJson: json['toolCallsJson'] as String?,
        toolResultsJson: json['toolResultsJson'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sessionId == other.sessionId;

  @override
  int get hashCode => Object.hash(id, sessionId);

  @override
  String toString() =>
      'Message(id: $id, sessionId: $sessionId, userId: $userId, kind: $messageKind)';
}

/// Convert a Message to the flat map format used by database/protocol.
Map<String, dynamic> messageToMap(Message msg) {
  return {
    'id': msg.id,
    'session_id': msg.sessionId,
    'user_id': msg.userId,
    'user_name': msg.userName,
    'content': msg.content,
    'created_at': msg.createdAt.millisecondsSinceEpoch,
    'edited_at': msg.editedAt?.millisecondsSinceEpoch,
    'message_kind': msg.messageKind.index,
    'image_url': msg.imageUrl,
    'tool_calls_json': msg.toolCallsJson,
    'tool_results_json': msg.toolResultsJson,
  };
}

/// Convert a flat map (from database/protocol) to a Message.
Message messageFromMap(Map<String, dynamic> map) {
  return Message(
    id: map['id'] as String,
    sessionId: map['session_id'] as String,
    userId: map['user_id'] as String,
    userName: map['user_name'] as String,
    content: map['content'] as String,
    createdAt: _parseDateTime(map['created_at']),
    editedAt:
        map['edited_at'] != null ? _parseDateTime(map['edited_at']) : null,
    messageKind: MessageKind.values[map['message_kind'] as int? ?? 0],
    imageUrl: map['image_url'] as String?,
    toolCallsJson: map['tool_calls_json'] as String?,
    toolResultsJson: map['tool_results_json'] as String?,
  );
}

DateTime _parseDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.parse(value);
  throw ArgumentError('Cannot parse DateTime from: $value');
}
