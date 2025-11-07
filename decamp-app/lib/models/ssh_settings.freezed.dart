// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ssh_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SshSettings _$SshSettingsFromJson(Map<String, dynamic> json) {
  return _SshSettings.fromJson(json);
}

/// @nodoc
mixin _$SshSettings {
  /// Hostname or IP address of the remote server
  String get host => throw _privateConstructorUsedError;

  /// SSH port (default is 22)
  int get port => throw _privateConstructorUsedError;

  /// Username for SSH authentication
  String get username => throw _privateConstructorUsedError;

  /// Authentication method (password or private key)
  SshAuthMethod get authMethod => throw _privateConstructorUsedError;

  /// Secret ID for password (stored in secrets table)
  /// Only used when authMethod is password
  String? get passwordSecretId => throw _privateConstructorUsedError;

  /// Secret ID for private key (stored in secrets table)
  /// Only used when authMethod is privateKey
  String? get privateKeySecretId => throw _privateConstructorUsedError;

  /// Optional passphrase secret ID for encrypted private keys
  String? get passphraseSecretId => throw _privateConstructorUsedError;

  /// Whether this configuration is enabled
  bool get enabled => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this SshSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SshSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SshSettingsCopyWith<SshSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SshSettingsCopyWith<$Res> {
  factory $SshSettingsCopyWith(
    SshSettings value,
    $Res Function(SshSettings) then,
  ) = _$SshSettingsCopyWithImpl<$Res, SshSettings>;
  @useResult
  $Res call({
    String host,
    int port,
    String username,
    SshAuthMethod authMethod,
    String? passwordSecretId,
    String? privateKeySecretId,
    String? passphraseSecretId,
    bool enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$SshSettingsCopyWithImpl<$Res, $Val extends SshSettings>
    implements $SshSettingsCopyWith<$Res> {
  _$SshSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SshSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? host = null,
    Object? port = null,
    Object? username = null,
    Object? authMethod = null,
    Object? passwordSecretId = freezed,
    Object? privateKeySecretId = freezed,
    Object? passphraseSecretId = freezed,
    Object? enabled = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            host: null == host
                ? _value.host
                : host // ignore: cast_nullable_to_non_nullable
                      as String,
            port: null == port
                ? _value.port
                : port // ignore: cast_nullable_to_non_nullable
                      as int,
            username: null == username
                ? _value.username
                : username // ignore: cast_nullable_to_non_nullable
                      as String,
            authMethod: null == authMethod
                ? _value.authMethod
                : authMethod // ignore: cast_nullable_to_non_nullable
                      as SshAuthMethod,
            passwordSecretId: freezed == passwordSecretId
                ? _value.passwordSecretId
                : passwordSecretId // ignore: cast_nullable_to_non_nullable
                      as String?,
            privateKeySecretId: freezed == privateKeySecretId
                ? _value.privateKeySecretId
                : privateKeySecretId // ignore: cast_nullable_to_non_nullable
                      as String?,
            passphraseSecretId: freezed == passphraseSecretId
                ? _value.passphraseSecretId
                : passphraseSecretId // ignore: cast_nullable_to_non_nullable
                      as String?,
            enabled: null == enabled
                ? _value.enabled
                : enabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SshSettingsImplCopyWith<$Res>
    implements $SshSettingsCopyWith<$Res> {
  factory _$$SshSettingsImplCopyWith(
    _$SshSettingsImpl value,
    $Res Function(_$SshSettingsImpl) then,
  ) = __$$SshSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String host,
    int port,
    String username,
    SshAuthMethod authMethod,
    String? passwordSecretId,
    String? privateKeySecretId,
    String? passphraseSecretId,
    bool enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$SshSettingsImplCopyWithImpl<$Res>
    extends _$SshSettingsCopyWithImpl<$Res, _$SshSettingsImpl>
    implements _$$SshSettingsImplCopyWith<$Res> {
  __$$SshSettingsImplCopyWithImpl(
    _$SshSettingsImpl _value,
    $Res Function(_$SshSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SshSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? host = null,
    Object? port = null,
    Object? username = null,
    Object? authMethod = null,
    Object? passwordSecretId = freezed,
    Object? privateKeySecretId = freezed,
    Object? passphraseSecretId = freezed,
    Object? enabled = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$SshSettingsImpl(
        host: null == host
            ? _value.host
            : host // ignore: cast_nullable_to_non_nullable
                  as String,
        port: null == port
            ? _value.port
            : port // ignore: cast_nullable_to_non_nullable
                  as int,
        username: null == username
            ? _value.username
            : username // ignore: cast_nullable_to_non_nullable
                  as String,
        authMethod: null == authMethod
            ? _value.authMethod
            : authMethod // ignore: cast_nullable_to_non_nullable
                  as SshAuthMethod,
        passwordSecretId: freezed == passwordSecretId
            ? _value.passwordSecretId
            : passwordSecretId // ignore: cast_nullable_to_non_nullable
                  as String?,
        privateKeySecretId: freezed == privateKeySecretId
            ? _value.privateKeySecretId
            : privateKeySecretId // ignore: cast_nullable_to_non_nullable
                  as String?,
        passphraseSecretId: freezed == passphraseSecretId
            ? _value.passphraseSecretId
            : passphraseSecretId // ignore: cast_nullable_to_non_nullable
                  as String?,
        enabled: null == enabled
            ? _value.enabled
            : enabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SshSettingsImpl implements _SshSettings {
  const _$SshSettingsImpl({
    required this.host,
    this.port = 22,
    required this.username,
    this.authMethod = SshAuthMethod.password,
    this.passwordSecretId,
    this.privateKeySecretId,
    this.passphraseSecretId,
    this.enabled = true,
    this.createdAt,
    this.updatedAt,
  });

  factory _$SshSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$SshSettingsImplFromJson(json);

  /// Hostname or IP address of the remote server
  @override
  final String host;

  /// SSH port (default is 22)
  @override
  @JsonKey()
  final int port;

  /// Username for SSH authentication
  @override
  final String username;

  /// Authentication method (password or private key)
  @override
  @JsonKey()
  final SshAuthMethod authMethod;

  /// Secret ID for password (stored in secrets table)
  /// Only used when authMethod is password
  @override
  final String? passwordSecretId;

  /// Secret ID for private key (stored in secrets table)
  /// Only used when authMethod is privateKey
  @override
  final String? privateKeySecretId;

  /// Optional passphrase secret ID for encrypted private keys
  @override
  final String? passphraseSecretId;

  /// Whether this configuration is enabled
  @override
  @JsonKey()
  final bool enabled;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'SshSettings(host: $host, port: $port, username: $username, authMethod: $authMethod, passwordSecretId: $passwordSecretId, privateKeySecretId: $privateKeySecretId, passphraseSecretId: $passphraseSecretId, enabled: $enabled, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SshSettingsImpl &&
            (identical(other.host, host) || other.host == host) &&
            (identical(other.port, port) || other.port == port) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.authMethod, authMethod) ||
                other.authMethod == authMethod) &&
            (identical(other.passwordSecretId, passwordSecretId) ||
                other.passwordSecretId == passwordSecretId) &&
            (identical(other.privateKeySecretId, privateKeySecretId) ||
                other.privateKeySecretId == privateKeySecretId) &&
            (identical(other.passphraseSecretId, passphraseSecretId) ||
                other.passphraseSecretId == passphraseSecretId) &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    host,
    port,
    username,
    authMethod,
    passwordSecretId,
    privateKeySecretId,
    passphraseSecretId,
    enabled,
    createdAt,
    updatedAt,
  );

  /// Create a copy of SshSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SshSettingsImplCopyWith<_$SshSettingsImpl> get copyWith =>
      __$$SshSettingsImplCopyWithImpl<_$SshSettingsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SshSettingsImplToJson(this);
  }
}

abstract class _SshSettings implements SshSettings {
  const factory _SshSettings({
    required final String host,
    final int port,
    required final String username,
    final SshAuthMethod authMethod,
    final String? passwordSecretId,
    final String? privateKeySecretId,
    final String? passphraseSecretId,
    final bool enabled,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) = _$SshSettingsImpl;

  factory _SshSettings.fromJson(Map<String, dynamic> json) =
      _$SshSettingsImpl.fromJson;

  /// Hostname or IP address of the remote server
  @override
  String get host;

  /// SSH port (default is 22)
  @override
  int get port;

  /// Username for SSH authentication
  @override
  String get username;

  /// Authentication method (password or private key)
  @override
  SshAuthMethod get authMethod;

  /// Secret ID for password (stored in secrets table)
  /// Only used when authMethod is password
  @override
  String? get passwordSecretId;

  /// Secret ID for private key (stored in secrets table)
  /// Only used when authMethod is privateKey
  @override
  String? get privateKeySecretId;

  /// Optional passphrase secret ID for encrypted private keys
  @override
  String? get passphraseSecretId;

  /// Whether this configuration is enabled
  @override
  bool get enabled;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of SshSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SshSettingsImplCopyWith<_$SshSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
