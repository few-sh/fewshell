// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_AppSettings', json, ($checkedConvert) {
      final val = _AppSettings(
        darkMode: $checkedConvert('darkMode', (v) => v as bool? ?? false),
        defaultAgentsMd: $checkedConvert(
          'defaultAgentsMd',
          (v) => v as String? ?? '',
        ),
        globalSecrets: $checkedConvert(
          'globalSecrets',
          (v) => v as Map<String, dynamic>?,
        ),
      );
      return val;
    });

Map<String, dynamic> _$AppSettingsToJson(_AppSettings instance) =>
    <String, dynamic>{
      'darkMode': instance.darkMode,
      'defaultAgentsMd': instance.defaultAgentsMd,
      'globalSecrets': instance.globalSecrets,
    };

_ProjectSettings _$ProjectSettingsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_ProjectSettings', json, ($checkedConvert) {
      final val = _ProjectSettings(
        projectId: $checkedConvert('projectId', (v) => v as String),
        agentsMd: $checkedConvert('agentsMd', (v) => v as String?),
        githubRepo: $checkedConvert('githubRepo', (v) => v as String?),
        githubBranch: $checkedConvert('githubBranch', (v) => v as String?),
        secrets: $checkedConvert(
          'secrets',
          (v) => (v as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ),
        ),
        enableGithubSync: $checkedConvert(
          'enableGithubSync',
          (v) => v as bool? ?? true,
        ),
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

Map<String, dynamic> _$ProjectSettingsToJson(_ProjectSettings instance) =>
    <String, dynamic>{
      'projectId': instance.projectId,
      'agentsMd': instance.agentsMd,
      'githubRepo': instance.githubRepo,
      'githubBranch': instance.githubBranch,
      'secrets': instance.secrets,
      'enableGithubSync': instance.enableGithubSync,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
