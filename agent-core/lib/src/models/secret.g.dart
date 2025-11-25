// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'secret.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SecretMetadataImpl _$$SecretMetadataImplFromJson(Map<String, dynamic> json) =>
    _$SecretMetadataImpl(
      id: json['id'] as String,
      projectId: json['projectId'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$SecretMetadataImplToJson(
        _$SecretMetadataImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'projectId': instance.projectId,
      'name': instance.name,
      'description': instance.description,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

_$SecretImpl _$$SecretImplFromJson(Map<String, dynamic> json) => _$SecretImpl(
      id: json['id'] as String,
      projectId: json['projectId'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      value: json['value'] as String,
    );

Map<String, dynamic> _$$SecretImplToJson(_$SecretImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'projectId': instance.projectId,
      'name': instance.name,
      'description': instance.description,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'value': instance.value,
    };
