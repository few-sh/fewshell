// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppSettingsImpl _$$AppSettingsImplFromJson(Map<String, dynamic> json) =>
    _$AppSettingsImpl(
      llmSettings: (json['llmSettings'] as List<dynamic>?)
              ?.map((e) => LlmApiSettings.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      defaultLlmIdentifier: json['defaultLlmIdentifier'] as String?,
      agentInstruction: json['agentInstruction'] == null
          ? null
          : AgentInstruction.fromJson(
              json['agentInstruction'] as Map<String, dynamic>),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$AppSettingsImplToJson(_$AppSettingsImpl instance) =>
    <String, dynamic>{
      'llmSettings': instance.llmSettings.map((e) => e.toJson()).toList(),
      'defaultLlmIdentifier': instance.defaultLlmIdentifier,
      'agentInstruction': instance.agentInstruction?.toJson(),
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

_$ProjectSettingsImpl _$$ProjectSettingsImplFromJson(
        Map<String, dynamic> json) =>
    _$ProjectSettingsImpl(
      projectId: json['projectId'] as String,
      llmSettings: (json['llmSettings'] as List<dynamic>?)
              ?.map((e) => LlmApiSettings.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      defaultLlmIdentifier: json['defaultLlmIdentifier'] as String?,
      agentInstruction: json['agentInstruction'] == null
          ? null
          : AgentInstruction.fromJson(
              json['agentInstruction'] as Map<String, dynamic>),
      includeUserInstructions:
          json['includeUserInstructions'] as bool? ?? false,
      sshSettings: json['sshSettings'] == null
          ? null
          : SshSettings.fromJson(json['sshSettings'] as Map<String, dynamic>),
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
      'llmSettings': instance.llmSettings.map((e) => e.toJson()).toList(),
      'defaultLlmIdentifier': instance.defaultLlmIdentifier,
      'agentInstruction': instance.agentInstruction?.toJson(),
      'includeUserInstructions': instance.includeUserInstructions,
      'sshSettings': instance.sshSettings?.toJson(),
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
