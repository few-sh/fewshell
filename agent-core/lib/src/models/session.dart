/// A chat session within a project.
///
/// Sessions contain a sequence of messages forming a conversation.
/// This model is shared between client and server.
class Session {
  /// Unique identifier
  final String id;

  /// Project this session belongs to
  final String projectId;

  /// Description/title of the session (often first message)
  final String description;

  /// When the session was created
  final DateTime createdAt;

  /// When the session was last updated (message added/edited)
  final DateTime updatedAt;

  /// Whether the session is archived
  final bool isArchived;

  const Session({
    required this.id,
    required this.projectId,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
  });

  Session copyWith({
    String? id,
    String? projectId,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
  }) {
    return Session(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isArchived': isArchived,
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        description: json['description'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        isArchived: json['isArchived'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Session &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          projectId == other.projectId &&
          description == other.description &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          isArchived == other.isArchived;

  @override
  int get hashCode => Object.hash(
        id,
        projectId,
        description,
        createdAt,
        updatedAt,
        isArchived,
      );

  @override
  String toString() =>
      'Session(id: $id, projectId: $projectId, description: $description)';
}
