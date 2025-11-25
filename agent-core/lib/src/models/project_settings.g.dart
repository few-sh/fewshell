// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProjectSettingsImpl _$$ProjectSettingsImplFromJson(
        Map<String, dynamic> json) =>
    _$ProjectSettingsImpl(
      projectId: json['projectId'] as String,
      name: json['name'] as String,
      llmSettings: (json['llmSettings'] as List<dynamic>?)
              ?.map((e) => LlmSettings.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      defaultLlmIdentifier: json['defaultLlmIdentifier'] as String?,
      sshSettings: json['sshSettings'] == null
          ? null
          : SshSettings.fromJson(json['sshSettings'] as Map<String, dynamic>),
      systemPrompt: json['systemPrompt'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$ProjectSettingsImplToJson(
        _$ProjectSettingsImpl instance) =>
    <String, dynamic>{
      'projectId': instance.projectId,
      'name': instance.name,
      'llmSettings': instance.llmSettings,
      'defaultLlmIdentifier': instance.defaultLlmIdentifier,
      'sshSettings': instance.sshSettings,
      'systemPrompt': instance.systemPrompt,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
