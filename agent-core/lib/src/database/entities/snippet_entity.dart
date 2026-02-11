import 'package:drift/drift.dart';

class SnippetEntity implements Insertable<SnippetEntity> {
  final String id;
  final String? projectId;
  final String name;
  final String content;
  final String? description;
  final String tags;
  final int position;
  final bool isVisibleToLlm;
  final bool autoApprove;
  final DateTime createdAt;
  final DateTime updatedAt;

  SnippetEntity({
    required this.id,
    this.projectId,
    required this.name,
    required this.content,
    this.description,
    required this.tags,
    required this.position,
    this.isVisibleToLlm = true,
    this.autoApprove = false,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    return {
      'id': Variable<String>(id),
      'project_id': Variable<String>(projectId),
      'name': Variable<String>(name),
      'content': Variable<String>(content),
      'description': Variable<String>(description),
      'tags': Variable<String>(tags),
      'position': Variable<int>(position),
      'is_visible_to_llm': Variable<bool>(isVisibleToLlm),
      'auto_approve': Variable<bool>(autoApprove),
      'created_at': Variable<DateTime>(createdAt),
      'updated_at': Variable<DateTime>(updatedAt),
    };
  }

  SnippetEntity copyWith({
    String? id,
    String? projectId,
    String? name,
    String? content,
    String? description,
    String? tags,
    int? position,
    bool? isVisibleToLlm,
    bool? autoApprove,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SnippetEntity(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      content: content ?? this.content,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      position: position ?? this.position,
      isVisibleToLlm: isVisibleToLlm ?? this.isVisibleToLlm,
      autoApprove: autoApprove ?? this.autoApprove,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
