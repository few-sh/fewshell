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
  /// List of configured LLM API endpoints at the global level
  List<LlmApiSettings> get llmSettings => throw _privateConstructorUsedError;

  /// Default LLM identifier to use when not overridden by project
  String? get defaultLlmIdentifier => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

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
    List<LlmApiSettings> llmSettings,
    String? defaultLlmIdentifier,
    DateTime? createdAt,
    DateTime? updatedAt,
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
    Object? llmSettings = null,
    Object? defaultLlmIdentifier = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            llmSettings: null == llmSettings
                ? _value.llmSettings
                : llmSettings // ignore: cast_nullable_to_non_nullable
                      as List<LlmApiSettings>,
            defaultLlmIdentifier: freezed == defaultLlmIdentifier
                ? _value.defaultLlmIdentifier
                : defaultLlmIdentifier // ignore: cast_nullable_to_non_nullable
                      as String?,
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
abstract class _$$AppSettingsImplCopyWith<$Res>
    implements $AppSettingsCopyWith<$Res> {
  factory _$$AppSettingsImplCopyWith(
    _$AppSettingsImpl value,
    $Res Function(_$AppSettingsImpl) then,
  ) = __$$AppSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<LlmApiSettings> llmSettings,
    String? defaultLlmIdentifier,
    DateTime? createdAt,
    DateTime? updatedAt,
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
    Object? llmSettings = null,
    Object? defaultLlmIdentifier = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$AppSettingsImpl(
        llmSettings: null == llmSettings
            ? _value._llmSettings
            : llmSettings // ignore: cast_nullable_to_non_nullable
                  as List<LlmApiSettings>,
        defaultLlmIdentifier: freezed == defaultLlmIdentifier
            ? _value.defaultLlmIdentifier
            : defaultLlmIdentifier // ignore: cast_nullable_to_non_nullable
                  as String?,
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
class _$AppSettingsImpl implements _AppSettings {
  const _$AppSettingsImpl({
    final List<LlmApiSettings> llmSettings = const [],
    this.defaultLlmIdentifier,
    this.createdAt,
    this.updatedAt,
  }) : _llmSettings = llmSettings;

  factory _$AppSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppSettingsImplFromJson(json);

  /// List of configured LLM API endpoints at the global level
  final List<LlmApiSettings> _llmSettings;

  /// List of configured LLM API endpoints at the global level
  @override
  @JsonKey()
  List<LlmApiSettings> get llmSettings {
    if (_llmSettings is EqualUnmodifiableListView) return _llmSettings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_llmSettings);
  }

  /// Default LLM identifier to use when not overridden by project
  @override
  final String? defaultLlmIdentifier;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'AppSettings(llmSettings: $llmSettings, defaultLlmIdentifier: $defaultLlmIdentifier, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppSettingsImpl &&
            const DeepCollectionEquality().equals(
              other._llmSettings,
              _llmSettings,
            ) &&
            (identical(other.defaultLlmIdentifier, defaultLlmIdentifier) ||
                other.defaultLlmIdentifier == defaultLlmIdentifier) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_llmSettings),
    defaultLlmIdentifier,
    createdAt,
    updatedAt,
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
    final List<LlmApiSettings> llmSettings,
    final String? defaultLlmIdentifier,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) = _$AppSettingsImpl;

  factory _AppSettings.fromJson(Map<String, dynamic> json) =
      _$AppSettingsImpl.fromJson;

  /// List of configured LLM API endpoints at the global level
  @override
  List<LlmApiSettings> get llmSettings;

  /// Default LLM identifier to use when not overridden by project
  @override
  String? get defaultLlmIdentifier;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

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

  /// List of configured LLM API endpoints for this project
  /// If empty, falls back to global settings
  List<LlmApiSettings> get llmSettings => throw _privateConstructorUsedError;

  /// Default LLM identifier for this project
  /// If null, falls back to global default
  String? get defaultLlmIdentifier => throw _privateConstructorUsedError;
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
    List<LlmApiSettings> llmSettings,
    String? defaultLlmIdentifier,
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
    Object? llmSettings = null,
    Object? defaultLlmIdentifier = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            projectId: null == projectId
                ? _value.projectId
                : projectId // ignore: cast_nullable_to_non_nullable
                      as String,
            llmSettings: null == llmSettings
                ? _value.llmSettings
                : llmSettings // ignore: cast_nullable_to_non_nullable
                      as List<LlmApiSettings>,
            defaultLlmIdentifier: freezed == defaultLlmIdentifier
                ? _value.defaultLlmIdentifier
                : defaultLlmIdentifier // ignore: cast_nullable_to_non_nullable
                      as String?,
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
    List<LlmApiSettings> llmSettings,
    String? defaultLlmIdentifier,
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
    Object? llmSettings = null,
    Object? defaultLlmIdentifier = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$ProjectSettingsImpl(
        projectId: null == projectId
            ? _value.projectId
            : projectId // ignore: cast_nullable_to_non_nullable
                  as String,
        llmSettings: null == llmSettings
            ? _value._llmSettings
            : llmSettings // ignore: cast_nullable_to_non_nullable
                  as List<LlmApiSettings>,
        defaultLlmIdentifier: freezed == defaultLlmIdentifier
            ? _value.defaultLlmIdentifier
            : defaultLlmIdentifier // ignore: cast_nullable_to_non_nullable
                  as String?,
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
    final List<LlmApiSettings> llmSettings = const [],
    this.defaultLlmIdentifier,
    this.createdAt,
    this.updatedAt,
  }) : _llmSettings = llmSettings;

  factory _$ProjectSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProjectSettingsImplFromJson(json);

  @override
  final String projectId;

  /// List of configured LLM API endpoints for this project
  /// If empty, falls back to global settings
  final List<LlmApiSettings> _llmSettings;

  /// List of configured LLM API endpoints for this project
  /// If empty, falls back to global settings
  @override
  @JsonKey()
  List<LlmApiSettings> get llmSettings {
    if (_llmSettings is EqualUnmodifiableListView) return _llmSettings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_llmSettings);
  }

  /// Default LLM identifier for this project
  /// If null, falls back to global default
  @override
  final String? defaultLlmIdentifier;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'ProjectSettings(projectId: $projectId, llmSettings: $llmSettings, defaultLlmIdentifier: $defaultLlmIdentifier, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProjectSettingsImpl &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            const DeepCollectionEquality().equals(
              other._llmSettings,
              _llmSettings,
            ) &&
            (identical(other.defaultLlmIdentifier, defaultLlmIdentifier) ||
                other.defaultLlmIdentifier == defaultLlmIdentifier) &&
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
    const DeepCollectionEquality().hash(_llmSettings),
    defaultLlmIdentifier,
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
    final List<LlmApiSettings> llmSettings,
    final String? defaultLlmIdentifier,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) = _$ProjectSettingsImpl;

  factory _ProjectSettings.fromJson(Map<String, dynamic> json) =
      _$ProjectSettingsImpl.fromJson;

  @override
  String get projectId;

  /// List of configured LLM API endpoints for this project
  /// If empty, falls back to global settings
  @override
  List<LlmApiSettings> get llmSettings;

  /// Default LLM identifier for this project
  /// If null, falls back to global default
  @override
  String? get defaultLlmIdentifier;
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
