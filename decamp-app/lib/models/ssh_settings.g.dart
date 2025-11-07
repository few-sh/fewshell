// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ssh_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SshSettingsImpl _$$SshSettingsImplFromJson(Map<String, dynamic> json) =>
    $checkedCreate(r'_$SshSettingsImpl', json, ($checkedConvert) {
      final val = _$SshSettingsImpl(
        host: $checkedConvert('host', (v) => v as String),
        port: $checkedConvert('port', (v) => (v as num?)?.toInt() ?? 22),
        username: $checkedConvert('username', (v) => v as String),
        authMethod: $checkedConvert(
          'authMethod',
          (v) =>
              $enumDecodeNullable(_$SshAuthMethodEnumMap, v) ??
              SshAuthMethod.password,
        ),
        passwordSecretId: $checkedConvert(
          'passwordSecretId',
          (v) => v as String?,
        ),
        privateKeySecretId: $checkedConvert(
          'privateKeySecretId',
          (v) => v as String?,
        ),
        passphraseSecretId: $checkedConvert(
          'passphraseSecretId',
          (v) => v as String?,
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

Map<String, dynamic> _$$SshSettingsImplToJson(_$SshSettingsImpl instance) =>
    <String, dynamic>{
      'host': instance.host,
      'port': instance.port,
      'username': instance.username,
      'authMethod': _$SshAuthMethodEnumMap[instance.authMethod]!,
      'passwordSecretId': instance.passwordSecretId,
      'privateKeySecretId': instance.privateKeySecretId,
      'passphraseSecretId': instance.passphraseSecretId,
      'enabled': instance.enabled,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$SshAuthMethodEnumMap = {
  SshAuthMethod.password: 'password',
  SshAuthMethod.privateKey: 'privateKey',
};
