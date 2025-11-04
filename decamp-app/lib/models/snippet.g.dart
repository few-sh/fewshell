// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'snippet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Snippet _$SnippetFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_Snippet', json, ($checkedConvert) {
  final val = _Snippet(
    id: $checkedConvert('id', (v) => v as String),
    projectId: $checkedConvert('projectId', (v) => v as String?),
    name: $checkedConvert('name', (v) => v as String),
    content: $checkedConvert('content', (v) => v as String),
    description: $checkedConvert('description', (v) => v as String?),
    tags: $checkedConvert(
      'tags',
      (v) =>
          (v as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
    ),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
    updatedAt: $checkedConvert('updatedAt', (v) => DateTime.parse(v as String)),
  );
  return val;
});

Map<String, dynamic> _$SnippetToJson(_Snippet instance) => <String, dynamic>{
  'id': instance.id,
  'projectId': instance.projectId,
  'name': instance.name,
  'content': instance.content,
  'description': instance.description,
  'tags': instance.tags,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
