// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LlmSettingsImpl _$$LlmSettingsImplFromJson(Map<String, dynamic> json) =>
    _$LlmSettingsImpl(
      identifier: json['identifier'] as String,
      provider: json['provider'] as String,
      model: json['model'] as String,
      baseUrl: json['baseUrl'] as String,
      apiKeySecretId: json['apiKeySecretId'] as String?,
      maxTokens: (json['maxTokens'] as num?)?.toInt(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      enabled: json['enabled'] as bool? ?? true,
    );

Map<String, dynamic> _$$LlmSettingsImplToJson(_$LlmSettingsImpl instance) =>
    <String, dynamic>{
      'identifier': instance.identifier,
      'provider': instance.provider,
      'model': instance.model,
      'baseUrl': instance.baseUrl,
      'apiKeySecretId': instance.apiKeySecretId,
      'maxTokens': instance.maxTokens,
      'temperature': instance.temperature,
      'enabled': instance.enabled,
    };
