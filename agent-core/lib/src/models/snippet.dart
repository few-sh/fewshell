/// A reusable text snippet (code, command, prompt fragment).
class Snippet {
  /// Unique identifier
  final String id;

  /// Project ID (null for global snippets)
  final String? projectId;

  /// Snippet name/title
  final String name;

  /// Snippet content
  final String content;

  /// Optional description
  final String? description;

  /// Tags for categorization
  final List<String> tags;

  /// Position for ordering (lower = higher in list)
  final int position;

  /// Creation timestamp
  final DateTime createdAt;

  /// Last updated timestamp
  final DateTime updatedAt;

  const Snippet({
    required this.id,
    this.projectId,
    required this.name,
    required this.content,
    this.description,
    this.tags = const [],
    this.position = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        if (projectId != null) 'projectId': projectId,
        'name': name,
        'content': content,
        if (description != null) 'description': description,
        'tags': tags,
        'position': position,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Snippet.fromJson(Map<String, dynamic> json) => Snippet(
        id: json['id'] as String,
        projectId: json['projectId'] as String?,
        name: json['name'] as String,
        content: json['content'] as String,
        description: json['description'] as String?,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        position: json['position'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Snippet copyWith({
    String? id,
    String? projectId,
    String? name,
    String? content,
    String? description,
    List<String>? tags,
    int? position,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Snippet(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        name: name ?? this.name,
        content: content ?? this.content,
        description: description ?? this.description,
        tags: tags ?? this.tags,
        position: position ?? this.position,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Snippet && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Snippet(id: $id, name: $name)';
}
