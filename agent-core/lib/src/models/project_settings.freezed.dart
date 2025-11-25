// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ProjectSettings _$ProjectSettingsFromJson(Map<String, dynamic> json) {
  return _ProjectSettings.fromJson(json);
}

/// @nodoc
mixin _$ProjectSettings {
  /// Project identifier
  String get projectId => throw _privateConstructorUsedError;

  /// Human-readable project name
  String get name => throw _privateConstructorUsedError;

  /// List of configured LLM endpoints for this project
  List<LlmSettings> get llmSettings => throw _privateConstructorUsedError;

  /// Default LLM identifier to use
  String? get defaultLlmIdentifier => throw _privateConstructorUsedError;

  /// SSH/Remote shell configuration
  SshSettings? get sshSettings => throw _privateConstructorUsedError;

  /// System prompt / agent instructions
  String? get systemPrompt => throw _privateConstructorUsedError;

  /// Creation timestamp
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Last updated timestamp
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
          ProjectSettings value, $Res Function(ProjectSettings) then) =
      _$ProjectSettingsCopyWithImpl<$Res, ProjectSettings>;
  @useResult
  $Res call(
      {String projectId,
      String name,
      List<LlmSettings> llmSettings,
      String? defaultLlmIdentifier,
      SshSettings? sshSettings,
      String? systemPrompt,
      DateTime? createdAt,
      DateTime? updatedAt});

  $SshSettingsCopyWith<$Res>? get sshSettings;
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
    Object? name = null,
    Object? llmSettings = null,
    Object? defaultLlmIdentifier = freezed,
    Object? sshSettings = freezed,
    Object? systemPrompt = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      projectId: null == projectId
          ? _value.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      llmSettings: null == llmSettings
          ? _value.llmSettings
          : llmSettings // ignore: cast_nullable_to_non_nullable
              as List<LlmSettings>,
      defaultLlmIdentifier: freezed == defaultLlmIdentifier
          ? _value.defaultLlmIdentifier
          : defaultLlmIdentifier // ignore: cast_nullable_to_non_nullable
              as String?,
      sshSettings: freezed == sshSettings
          ? _value.sshSettings
          : sshSettings // ignore: cast_nullable_to_non_nullable
              as SshSettings?,
      systemPrompt: freezed == systemPrompt
          ? _value.systemPrompt
          : systemPrompt // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }

  /// Create a copy of ProjectSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SshSettingsCopyWith<$Res>? get sshSettings {
    if (_value.sshSettings == null) {
      return null;
    }

    return $SshSettingsCopyWith<$Res>(_value.sshSettings!, (value) {
      return _then(_value.copyWith(sshSettings: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ProjectSettingsImplCopyWith<$Res>
    implements $ProjectSettingsCopyWith<$Res> {
  factory _$$ProjectSettingsImplCopyWith(_$ProjectSettingsImpl value,
          $Res Function(_$ProjectSettingsImpl) then) =
      __$$ProjectSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String projectId,
      String name,
      List<LlmSettings> llmSettings,
      String? defaultLlmIdentifier,
      SshSettings? sshSettings,
      String? systemPrompt,
      DateTime? createdAt,
      DateTime? updatedAt});

  @override
  $SshSettingsCopyWith<$Res>? get sshSettings;
}

/// @nodoc
class __$$ProjectSettingsImplCopyWithImpl<$Res>
    extends _$ProjectSettingsCopyWithImpl<$Res, _$ProjectSettingsImpl>
    implements _$$ProjectSettingsImplCopyWith<$Res> {
  __$$ProjectSettingsImplCopyWithImpl(
      _$ProjectSettingsImpl _value, $Res Function(_$ProjectSettingsImpl) _then)
      : super(_value, _then);

  /// Create a copy of ProjectSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? projectId = null,
    Object? name = null,
    Object? llmSettings = null,
    Object? defaultLlmIdentifier = freezed,
    Object? sshSettings = freezed,
    Object? systemPrompt = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$ProjectSettingsImpl(
      projectId: null == projectId
          ? _value.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      llmSettings: null == llmSettings
          ? _value._llmSettings
          : llmSettings // ignore: cast_nullable_to_non_nullable
              as List<LlmSettings>,
      defaultLlmIdentifier: freezed == defaultLlmIdentifier
          ? _value.defaultLlmIdentifier
          : defaultLlmIdentifier // ignore: cast_nullable_to_non_nullable
              as String?,
      sshSettings: freezed == sshSettings
          ? _value.sshSettings
          : sshSettings // ignore: cast_nullable_to_non_nullable
              as SshSettings?,
      systemPrompt: freezed == systemPrompt
          ? _value.systemPrompt
          : systemPrompt // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ProjectSettingsImpl extends _ProjectSettings {
  const _$ProjectSettingsImpl(
      {required this.projectId,
      required this.name,
      final List<LlmSettings> llmSettings = const [],
      this.defaultLlmIdentifier,
      this.sshSettings,
      this.systemPrompt,
      this.createdAt,
      this.updatedAt})
      : _llmSettings = llmSettings,
        super._();

  factory _$ProjectSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProjectSettingsImplFromJson(json);

  /// Project identifier
  @override
  final String projectId;

  /// Human-readable project name
  @override
  final String name;

  /// List of configured LLM endpoints for this project
  final List<LlmSettings> _llmSettings;

  /// List of configured LLM endpoints for this project
  @override
  @JsonKey()
  List<LlmSettings> get llmSettings {
    if (_llmSettings is EqualUnmodifiableListView) return _llmSettings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_llmSettings);
  }

  /// Default LLM identifier to use
  @override
  final String? defaultLlmIdentifier;

  /// SSH/Remote shell configuration
  @override
  final SshSettings? sshSettings;

  /// System prompt / agent instructions
  @override
  final String? systemPrompt;

  /// Creation timestamp
  @override
  final DateTime? createdAt;

  /// Last updated timestamp
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'ProjectSettings(projectId: $projectId, name: $name, llmSettings: $llmSettings, defaultLlmIdentifier: $defaultLlmIdentifier, sshSettings: $sshSettings, systemPrompt: $systemPrompt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProjectSettingsImpl &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality()
                .equals(other._llmSettings, _llmSettings) &&
            (identical(other.defaultLlmIdentifier, defaultLlmIdentifier) ||
                other.defaultLlmIdentifier == defaultLlmIdentifier) &&
            (identical(other.sshSettings, sshSettings) ||
                other.sshSettings == sshSettings) &&
            (identical(other.systemPrompt, systemPrompt) ||
                other.systemPrompt == systemPrompt) &&
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
      name,
      const DeepCollectionEquality().hash(_llmSettings),
      defaultLlmIdentifier,
      sshSettings,
      systemPrompt,
      createdAt,
      updatedAt);

  /// Create a copy of ProjectSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProjectSettingsImplCopyWith<_$ProjectSettingsImpl> get copyWith =>
      __$$ProjectSettingsImplCopyWithImpl<_$ProjectSettingsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProjectSettingsImplToJson(
      this,
    );
  }
}

abstract class _ProjectSettings extends ProjectSettings {
  const factory _ProjectSettings(
      {required final String projectId,
      required final String name,
      final List<LlmSettings> llmSettings,
      final String? defaultLlmIdentifier,
      final SshSettings? sshSettings,
      final String? systemPrompt,
      final DateTime? createdAt,
      final DateTime? updatedAt}) = _$ProjectSettingsImpl;
  const _ProjectSettings._() : super._();

  factory _ProjectSettings.fromJson(Map<String, dynamic> json) =
      _$ProjectSettingsImpl.fromJson;

  /// Project identifier
  @override
  String get projectId;

  /// Human-readable project name
  @override
  String get name;

  /// List of configured LLM endpoints for this project
  @override
  List<LlmSettings> get llmSettings;

  /// Default LLM identifier to use
  @override
  String? get defaultLlmIdentifier;

  /// SSH/Remote shell configuration
  @override
  SshSettings? get sshSettings;

  /// System prompt / agent instructions
  @override
  String? get systemPrompt;

  /// Creation timestamp
  @override
  DateTime? get createdAt;

  /// Last updated timestamp
  @override
  DateTime? get updatedAt;

  /// Create a copy of ProjectSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProjectSettingsImplCopyWith<_$ProjectSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
