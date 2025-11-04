// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'secret.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Secret _$SecretFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_Secret', json, ($checkedConvert) {
  final val = _Secret(
    id: $checkedConvert('id', (v) => v as String),
    projectId: $checkedConvert('projectId', (v) => v as String?),
    key: $checkedConvert('key', (v) => v as String),
    description: $checkedConvert('description', (v) => v as String),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
    updatedAt: $checkedConvert('updatedAt', (v) => DateTime.parse(v as String)),
  );
  return val;
});

Map<String, dynamic> _$SecretToJson(_Secret instance) => <String, dynamic>{
  'id': instance.id,
  'projectId': instance.projectId,
  'key': instance.key,
  'description': instance.description,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
