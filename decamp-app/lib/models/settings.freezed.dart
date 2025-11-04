// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) {
  return _AppSettings.fromJson(json);
}

/// @nodoc
mixin _$AppSettings {
  bool get darkMode => throw _privateConstructorUsedError;
  String get defaultAgentsMd => throw _privateConstructorUsedError;
  Map<String, dynamic>? get globalSecrets => throw _privateConstructorUsedError;

  /// Serializes this AppSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppSettingsCopyWith<AppSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppSettingsCopyWith<$Res> {
  factory $AppSettingsCopyWith(
    AppSettings value,
    $Res Function(AppSettings) then,
  ) = _$AppSettingsCopyWithImpl<$Res, AppSettings>;
  @useResult
  $Res call({
    bool darkMode,
    String defaultAgentsMd,
    Map<String, dynamic>? globalSecrets,
  });
}

/// @nodoc
class _$AppSettingsCopyWithImpl<$Res, $Val extends AppSettings>
    implements $AppSettingsCopyWith<$Res> {
  _$AppSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? darkMode = null,
    Object? defaultAgentsMd = null,
    Object? globalSecrets = freezed,
  }) {
    return _then(
      _value.copyWith(
            darkMode: null == darkMode
                ? _value.darkMode
                : darkMode // ignore: cast_nullable_to_non_nullable
                      as bool,
            defaultAgentsMd: null == defaultAgentsMd
                ? _value.defaultAgentsMd
                : defaultAgentsMd // ignore: cast_nullable_to_non_nullable
                      as String,
            globalSecrets: freezed == globalSecrets
                ? _value.globalSecrets
                : globalSecrets // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AppSettingsImplCopyWith<$Res>
    implements $AppSettingsCopyWith<$Res> {
  factory _$$AppSettingsImplCopyWith(
    _$AppSettingsImpl value,
    $Res Function(_$AppSettingsImpl) then,
  ) = __$$AppSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool darkMode,
    String defaultAgentsMd,
    Map<String, dynamic>? globalSecrets,
  });
}

/// @nodoc
class __$$AppSettingsImplCopyWithImpl<$Res>
    extends _$AppSettingsCopyWithImpl<$Res, _$AppSettingsImpl>
    implements _$$AppSettingsImplCopyWith<$Res> {
  __$$AppSettingsImplCopyWithImpl(
    _$AppSettingsImpl _value,
    $Res Function(_$AppSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? darkMode = null,
    Object? defaultAgentsMd = null,
    Object? globalSecrets = freezed,
  }) {
    return _then(
      _$AppSettingsImpl(
        darkMode: null == darkMode
            ? _value.darkMode
            : darkMode // ignore: cast_nullable_to_non_nullable
                  as bool,
        defaultAgentsMd: null == defaultAgentsMd
            ? _value.defaultAgentsMd
            : defaultAgentsMd // ignore: cast_nullable_to_non_nullable
                  as String,
        globalSecrets: freezed == globalSecrets
            ? _value._globalSecrets
            : globalSecrets // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AppSettingsImpl implements _AppSettings {
  const _$AppSettingsImpl({
    this.darkMode = false,
    this.defaultAgentsMd = '',
    final Map<String, dynamic>? globalSecrets,
  }) : _globalSecrets = globalSecrets;

  factory _$AppSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppSettingsImplFromJson(json);

  @override
  @JsonKey()
  final bool darkMode;
  @override
  @JsonKey()
  final String defaultAgentsMd;
  final Map<String, dynamic>? _globalSecrets;
  @override
  Map<String, dynamic>? get globalSecrets {
    final value = _globalSecrets;
    if (value == null) return null;
    if (_globalSecrets is EqualUnmodifiableMapView) return _globalSecrets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'AppSettings(darkMode: $darkMode, defaultAgentsMd: $defaultAgentsMd, globalSecrets: $globalSecrets)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppSettingsImpl &&
            (identical(other.darkMode, darkMode) ||
                other.darkMode == darkMode) &&
            (identical(other.defaultAgentsMd, defaultAgentsMd) ||
                other.defaultAgentsMd == defaultAgentsMd) &&
            const DeepCollectionEquality().equals(
              other._globalSecrets,
              _globalSecrets,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    darkMode,
    defaultAgentsMd,
    const DeepCollectionEquality().hash(_globalSecrets),
  );

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppSettingsImplCopyWith<_$AppSettingsImpl> get copyWith =>
      __$$AppSettingsImplCopyWithImpl<_$AppSettingsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AppSettingsImplToJson(this);
  }
}

abstract class _AppSettings implements AppSettings {
  const factory _AppSettings({
    final bool darkMode,
    final String defaultAgentsMd,
    final Map<String, dynamic>? globalSecrets,
  }) = _$AppSettingsImpl;

  factory _AppSettings.fromJson(Map<String, dynamic> json) =
      _$AppSettingsImpl.fromJson;

  @override
  bool get darkMode;
  @override
  String get defaultAgentsMd;
  @override
  Map<String, dynamic>? get globalSecrets;

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppSettingsImplCopyWith<_$AppSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ProjectSettings _$ProjectSettingsFromJson(Map<String, dynamic> json) {
  return _ProjectSettings.fromJson(json);
}

/// @nodoc
mixin _$ProjectSettings {
  String get projectId => throw _privateConstructorUsedError;
  String? get agentsMd => throw _privateConstructorUsedError;
  String? get githubRepo => throw _privateConstructorUsedError;
  String? get githubBranch => throw _privateConstructorUsedError;
  Map<String, String>? get secrets => throw _privateConstructorUsedError;
  bool get enableGithubSync => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this ProjectSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProjectSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProjectSettingsCopyWith<ProjectSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProjectSettingsCopyWith<$Res> {
  factory $ProjectSettingsCopyWith(
    ProjectSettings value,
    $Res Function(ProjectSettings) then,
  ) = _$ProjectSettingsCopyWithImpl<$Res, ProjectSettings>;
  @useResult
  $Res call({
    String projectId,
    String? agentsMd,
    String? githubRepo,
    String? githubBranch,
    Map<String, String>? secrets,
    bool enableGithubSync,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$ProjectSettingsCopyWithImpl<$Res, $Val extends ProjectSettings>
    implements $ProjectSettingsCopyWith<$Res> {
  _$ProjectSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProjectSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? projectId = null,
    Object? agentsMd = freezed,
    Object? githubRepo = freezed,
    Object? githubBranch = freezed,
    Object? secrets = freezed,
    Object? enableGithubSync = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            projectId: null == projectId
                ? _value.projectId
                : projectId // ignore: cast_nullable_to_non_nullable
                      as String,
            agentsMd: freezed == agentsMd
                ? _value.agentsMd
                : agentsMd // ignore: cast_nullable_to_non_nullable
                      as String?,
            githubRepo: freezed == githubRepo
                ? _value.githubRepo
                : githubRepo // ignore: cast_nullable_to_non_nullable
                      as String?,
            githubBranch: freezed == githubBranch
                ? _value.githubBranch
                : githubBranch // ignore: cast_nullable_to_non_nullable
                      as String?,
            secrets: freezed == secrets
                ? _value.secrets
                : secrets // ignore: cast_nullable_to_non_nullable
                      as Map<String, String>?,
            enableGithubSync: null == enableGithubSync
                ? _value.enableGithubSync
                : enableGithubSync // ignore: cast_nullable_to_non_nullable
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
abstract class _$$ProjectSettingsImplCopyWith<$Res>
    implements $ProjectSettingsCopyWith<$Res> {
  factory _$$ProjectSettingsImplCopyWith(
    _$ProjectSettingsImpl value,
    $Res Function(_$ProjectSettingsImpl) then,
  ) = __$$ProjectSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String projectId,
    String? agentsMd,
    String? githubRepo,
    String? githubBranch,
    Map<String, String>? secrets,
    bool enableGithubSync,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$ProjectSettingsImplCopyWithImpl<$Res>
    extends _$ProjectSettingsCopyWithImpl<$Res, _$ProjectSettingsImpl>
    implements _$$ProjectSettingsImplCopyWith<$Res> {
  __$$ProjectSettingsImplCopyWithImpl(
    _$ProjectSettingsImpl _value,
    $Res Function(_$ProjectSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProjectSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? projectId = null,
    Object? agentsMd = freezed,
    Object? githubRepo = freezed,
    Object? githubBranch = freezed,
    Object? secrets = freezed,
    Object? enableGithubSync = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$ProjectSettingsImpl(
        projectId: null == projectId
            ? _value.projectId
            : projectId // ignore: cast_nullable_to_non_nullable
                  as String,
        agentsMd: freezed == agentsMd
            ? _value.agentsMd
            : agentsMd // ignore: cast_nullable_to_non_nullable
                  as String?,
        githubRepo: freezed == githubRepo
            ? _value.githubRepo
            : githubRepo // ignore: cast_nullable_to_non_nullable
                  as String?,
        githubBranch: freezed == githubBranch
            ? _value.githubBranch
            : githubBranch // ignore: cast_nullable_to_non_nullable
                  as String?,
        secrets: freezed == secrets
            ? _value._secrets
            : secrets // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>?,
        enableGithubSync: null == enableGithubSync
            ? _value.enableGithubSync
            : enableGithubSync // ignore: cast_nullable_to_non_nullable
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
class _$ProjectSettingsImpl implements _ProjectSettings {
  const _$ProjectSettingsImpl({
    required this.projectId,
    this.agentsMd,
    this.githubRepo,
    this.githubBranch,
    final Map<String, String>? secrets,
    this.enableGithubSync = true,
    this.createdAt,
    this.updatedAt,
  }) : _secrets = secrets;

  factory _$ProjectSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProjectSettingsImplFromJson(json);

  @override
  final String projectId;
  @override
  final String? agentsMd;
  @override
  final String? githubRepo;
  @override
  final String? githubBranch;
  final Map<String, String>? _secrets;
  @override
  Map<String, String>? get secrets {
    final value = _secrets;
    if (value == null) return null;
    if (_secrets is EqualUnmodifiableMapView) return _secrets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey()
  final bool enableGithubSync;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'ProjectSettings(projectId: $projectId, agentsMd: $agentsMd, githubRepo: $githubRepo, githubBranch: $githubBranch, secrets: $secrets, enableGithubSync: $enableGithubSync, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProjectSettingsImpl &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            (identical(other.agentsMd, agentsMd) ||
                other.agentsMd == agentsMd) &&
            (identical(other.githubRepo, githubRepo) ||
                other.githubRepo == githubRepo) &&
            (identical(other.githubBranch, githubBranch) ||
                other.githubBranch == githubBranch) &&
            const DeepCollectionEquality().equals(other._secrets, _secrets) &&
            (identical(other.enableGithubSync, enableGithubSync) ||
                other.enableGithubSync == enableGithubSync) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    projectId,
    agentsMd,
    githubRepo,
    githubBranch,
    const DeepCollectionEquality().hash(_secrets),
    enableGithubSync,
    createdAt,
    updatedAt,
  );

  /// Create a copy of ProjectSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProjectSettingsImplCopyWith<_$ProjectSettingsImpl> get copyWith =>
      __$$ProjectSettingsImplCopyWithImpl<_$ProjectSettingsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ProjectSettingsImplToJson(this);
  }
}

abstract class _ProjectSettings implements ProjectSettings {
  const factory _ProjectSettings({
    required final String projectId,
    final String? agentsMd,
    final String? githubRepo,
    final String? githubBranch,
    final Map<String, String>? secrets,
    final bool enableGithubSync,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) = _$ProjectSettingsImpl;

  factory _ProjectSettings.fromJson(Map<String, dynamic> json) =
      _$ProjectSettingsImpl.fromJson;

  @override
  String get projectId;
  @override
  String? get agentsMd;
  @override
  String? get githubRepo;
  @override
  String? get githubBranch;
  @override
  Map<String, String>? get secrets;
  @override
  bool get enableGithubSync;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of ProjectSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProjectSettingsImplCopyWith<_$ProjectSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
