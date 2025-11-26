// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ssh_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SshSettingsImpl _$$SshSettingsImplFromJson(Map<String, dynamic> json) =>
    _$SshSettingsImpl(
      host: json['host'] as String,
      port: (json['port'] as num?)?.toInt() ?? 22,
      username: json['username'] as String,
      authMethod:
          $enumDecodeNullable(_$SshAuthMethodEnumMap, json['authMethod']) ??
              SshAuthMethod.password,
      passwordSecretId: json['passwordSecretId'] as String?,
      privateKeySecretId: json['privateKeySecretId'] as String?,
      passphraseSecretId: json['passphraseSecretId'] as String?,
      sudoPasswordSecretId: json['sudoPasswordSecretId'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$SshSettingsImplToJson(_$SshSettingsImpl instance) =>
    <String, dynamic>{
      'host': instance.host,
      'port': instance.port,
      'username': instance.username,
      'authMethod': _$SshAuthMethodEnumMap[instance.authMethod]!,
      'passwordSecretId': instance.passwordSecretId,
      'privateKeySecretId': instance.privateKeySecretId,
      'passphraseSecretId': instance.passphraseSecretId,
      'sudoPasswordSecretId': instance.sudoPasswordSecretId,
      'enabled': instance.enabled,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$SshAuthMethodEnumMap = {
  SshAuthMethod.password: 'password',
  SshAuthMethod.privateKey: 'privateKey',
};
