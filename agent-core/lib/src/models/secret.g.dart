// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'secret.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Secret _$SecretFromJson(Map<String, dynamic> json) => Secret(
      value: json['value'] as String,
      isVisibleToLlm: json['isVisibleToLlm'] as bool? ?? true,
      isSystem: json['isSystem'] as bool? ?? false,
    );

Map<String, dynamic> _$SecretToJson(Secret instance) => <String, dynamic>{
      'value': instance.value,
      'isVisibleToLlm': instance.isVisibleToLlm,
      'isSystem': instance.isSystem,
    };
