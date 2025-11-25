// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'snippet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SnippetImpl _$$SnippetImplFromJson(Map<String, dynamic> json) =>
    _$SnippetImpl(
      id: json['id'] as String,
      projectId: json['projectId'] as String?,
      name: json['name'] as String,
      content: json['content'] as String,
      description: json['description'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      position: (json['position'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$SnippetImplToJson(_$SnippetImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'projectId': instance.projectId,
      'name': instance.name,
      'content': instance.content,
      'description': instance.description,
      'tags': instance.tags,
      'position': instance.position,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
