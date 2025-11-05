// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_api_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LlmApiSettingsImpl _$$LlmApiSettingsImplFromJson(Map<String, dynamic> json) =>
    $checkedCreate(r'_$LlmApiSettingsImpl', json, ($checkedConvert) {
      final val = _$LlmApiSettingsImpl(
        identifier: $checkedConvert('identifier', (v) => v as String),
        displayName: $checkedConvert('displayName', (v) => v as String),
        baseUrl: $checkedConvert('baseUrl', (v) => v as String),
        modelName: $checkedConvert('modelName', (v) => v as String?),
        customHeaders: $checkedConvert('customHeaders', (v) => v as String?),
        maxTokens: $checkedConvert('maxTokens', (v) => (v as num?)?.toInt()),
        temperature: $checkedConvert(
          'temperature',
          (v) => (v as num?)?.toDouble(),
        ),
        enabled: $checkedConvert('enabled', (v) => v as bool? ?? true),
        createdAt: $checkedConvert(
          'createdAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
        updatedAt: $checkedConvert(
          'updatedAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$$LlmApiSettingsImplToJson(
  _$LlmApiSettingsImpl instance,
) => <String, dynamic>{
  'identifier': instance.identifier,
  'displayName': instance.displayName,
  'baseUrl': instance.baseUrl,
  'modelName': instance.modelName,
  'customHeaders': instance.customHeaders,
  'maxTokens': instance.maxTokens,
  'temperature': instance.temperature,
  'enabled': instance.enabled,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
