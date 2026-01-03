// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'secret.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Secret _$SecretFromJson(Map<String, dynamic> json) => Secret(
      value: json['value'] as String,
      isVisibleToLlm: json['isVisibleToLlm'] as bool? ?? true,
    );

Map<String, dynamic> _$SecretToJson(Secret instance) => <String, dynamic>{
      'value': instance.value,
      'isVisibleToLlm': instance.isVisibleToLlm,
    };
