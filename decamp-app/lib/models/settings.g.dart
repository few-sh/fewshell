// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppSettingsImpl _$$AppSettingsImplFromJson(Map<String, dynamic> json) =>
    $checkedCreate(r'_$AppSettingsImpl', json, ($checkedConvert) {
      final val = _$AppSettingsImpl(
        llmSettings: $checkedConvert(
          'llmSettings',
          (v) =>
              (v as List<dynamic>?)
                  ?.map(
                    (e) => LlmApiSettings.fromJson(e as Map<String, dynamic>),
                  )
                  .toList() ??
              const [],
        ),
        defaultLlmIdentifier: $checkedConvert(
          'defaultLlmIdentifier',
          (v) => v as String?,
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

Map<String, dynamic> _$$AppSettingsImplToJson(_$AppSettingsImpl instance) =>
    <String, dynamic>{
      'llmSettings': instance.llmSettings,
      'defaultLlmIdentifier': instance.defaultLlmIdentifier,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

_$ProjectSettingsImpl _$$ProjectSettingsImplFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(r'_$ProjectSettingsImpl', json, ($checkedConvert) {
  final val = _$ProjectSettingsImpl(
    projectId: $checkedConvert('projectId', (v) => v as String),
    llmSettings: $checkedConvert(
      'llmSettings',
      (v) =>
          (v as List<dynamic>?)
              ?.map((e) => LlmApiSettings.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    ),
    defaultLlmIdentifier: $checkedConvert(
      'defaultLlmIdentifier',
      (v) => v as String?,
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
  'llmSettings': instance.llmSettings,
  'defaultLlmIdentifier': instance.defaultLlmIdentifier,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
