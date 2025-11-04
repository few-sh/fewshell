// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppSettingsImpl _$$AppSettingsImplFromJson(Map<String, dynamic> json) =>
    $checkedCreate(r'_$AppSettingsImpl', json, ($checkedConvert) {
      final val = _$AppSettingsImpl(
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

Map<String, dynamic> _$$AppSettingsImplToJson(_$AppSettingsImpl instance) =>
    <String, dynamic>{
      'darkMode': instance.darkMode,
      'defaultAgentsMd': instance.defaultAgentsMd,
      'globalSecrets': instance.globalSecrets,
    };

_$ProjectSettingsImpl _$$ProjectSettingsImplFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(r'_$ProjectSettingsImpl', json, ($checkedConvert) {
  final val = _$ProjectSettingsImpl(
    projectId: $checkedConvert('projectId', (v) => v as String),
    agentsMd: $checkedConvert('agentsMd', (v) => v as String?),
    githubRepo: $checkedConvert('githubRepo', (v) => v as String?),
    githubBranch: $checkedConvert('githubBranch', (v) => v as String?),
    secrets: $checkedConvert(
      'secrets',
      (v) =>
          (v as Map<String, dynamic>?)?.map((k, e) => MapEntry(k, e as String)),
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

Map<String, dynamic> _$$ProjectSettingsImplToJson(
  _$ProjectSettingsImpl instance,
) => <String, dynamic>{
  'projectId': instance.projectId,
  'agentsMd': instance.agentsMd,
  'githubRepo': instance.githubRepo,
  'githubBranch': instance.githubBranch,
  'secrets': instance.secrets,
  'enableGithubSync': instance.enableGithubSync,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
