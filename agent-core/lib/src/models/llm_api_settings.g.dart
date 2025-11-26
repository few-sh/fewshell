// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_api_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LlmApiSettingsImpl _$$LlmApiSettingsImplFromJson(Map<String, dynamic> json) =>
    _$LlmApiSettingsImpl(
      identifier: json['identifier'] as String,
      apiType: $enumDecode(_$LlmApiTypeEnumMap, json['apiType']),
      baseUrl: json['baseUrl'] as String,
      customHeaders: json['customHeaders'] as String?,
      maxTokens: (json['maxTokens'] as num?)?.toInt(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      enabled: json['enabled'] as bool? ?? true,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$LlmApiSettingsImplToJson(
        _$LlmApiSettingsImpl instance) =>
    <String, dynamic>{
      'identifier': instance.identifier,
      'apiType': _$LlmApiTypeEnumMap[instance.apiType]!,
      'baseUrl': instance.baseUrl,
      'customHeaders': instance.customHeaders,
      'maxTokens': instance.maxTokens,
      'temperature': instance.temperature,
      'enabled': instance.enabled,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$LlmApiTypeEnumMap = {
  LlmApiType.openai: 'openai',
  LlmApiType.anthropic: 'anthropic',
  LlmApiType.google: 'google',
  LlmApiType.deepseek: 'deepseek',
  LlmApiType.groq: 'groq',
  LlmApiType.ollama: 'ollama',
  LlmApiType.xai: 'xai',
  LlmApiType.openaiCompatible: 'openaiCompatible',
};
