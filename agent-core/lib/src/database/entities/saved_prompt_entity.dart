import 'package:drift/drift.dart';

class SavedPromptEntity implements Insertable<SavedPromptEntity> {
  final String id;
  final String? projectId;
  final String content;
  final String? description;
  final String tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;

  SavedPromptEntity({
    required this.id,
    this.projectId,
    required this.content,
    this.description,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    return {
      'id': Variable<String>(id),
      'project_id': Variable<String>(projectId),
      'content': Variable<String>(content),
      'description': Variable<String>(description),
      'tags': Variable<String>(tags),
      'created_at': Variable<DateTime>(createdAt),
      'updated_at': Variable<DateTime>(updatedAt),
      'last_used_at': Variable<DateTime>(lastUsedAt),
    };
  }

  SavedPromptEntity copyWith({
    String? id,
    String? projectId,
    String? content,
    String? description,
    String? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
  }) {
    return SavedPromptEntity(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      content: content ?? this.content,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }
}
