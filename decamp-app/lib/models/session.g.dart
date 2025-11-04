// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SessionImpl _$$SessionImplFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(r'_$SessionImpl', json, ($checkedConvert) {
  final val = _$SessionImpl(
    id: $checkedConvert('id', (v) => v as String),
    projectId: $checkedConvert('projectId', (v) => v as String),
    description: $checkedConvert('description', (v) => v as String),
    timestamp: $checkedConvert('timestamp', (v) => DateTime.parse(v as String)),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
    updatedAt: $checkedConvert('updatedAt', (v) => DateTime.parse(v as String)),
  );
  return val;
});

Map<String, dynamic> _$$SessionImplToJson(_$SessionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'projectId': instance.projectId,
      'description': instance.description,
      'timestamp': instance.timestamp.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
