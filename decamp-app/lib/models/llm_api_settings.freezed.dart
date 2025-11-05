// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'llm_api_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

LlmApiSettings _$LlmApiSettingsFromJson(Map<String, dynamic> json) {
  return _LlmApiSettings.fromJson(json);
}

/// @nodoc
mixin _$LlmApiSettings {
  /// Unique identifier for this LLM configuration (e.g., "gpt-4-turbo", "claude-3-5-sonnet")
  String get identifier => throw _privateConstructorUsedError;

  /// Base URL for the API endpoint
  String get baseUrl => throw _privateConstructorUsedError;

  /// Optional: Additional headers to include in requests (as JSON string)
  /// Format: {"Header-Name": "value", ...}
  String? get customHeaders => throw _privateConstructorUsedError;

  /// Optional: Maximum tokens for this model
  int? get maxTokens => throw _privateConstructorUsedError;

  /// Optional: Default temperature setting
  double? get temperature => throw _privateConstructorUsedError;

  /// Whether this model is currently enabled
  bool get enabled => throw _privateConstructorUsedError;

  /// Creation timestamp
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Last updated timestamp
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this LlmApiSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LlmApiSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LlmApiSettingsCopyWith<LlmApiSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LlmApiSettingsCopyWith<$Res> {
  factory $LlmApiSettingsCopyWith(
    LlmApiSettings value,
    $Res Function(LlmApiSettings) then,
  ) = _$LlmApiSettingsCopyWithImpl<$Res, LlmApiSettings>;
  @useResult
  $Res call({
    String identifier,
    String baseUrl,
    String? customHeaders,
    int? maxTokens,
    double? temperature,
    bool enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$LlmApiSettingsCopyWithImpl<$Res, $Val extends LlmApiSettings>
    implements $LlmApiSettingsCopyWith<$Res> {
  _$LlmApiSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LlmApiSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? identifier = null,
    Object? baseUrl = null,
    Object? customHeaders = freezed,
    Object? maxTokens = freezed,
    Object? temperature = freezed,
    Object? enabled = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            identifier: null == identifier
                ? _value.identifier
                : identifier // ignore: cast_nullable_to_non_nullable
                      as String,
            baseUrl: null == baseUrl
                ? _value.baseUrl
                : baseUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            customHeaders: freezed == customHeaders
                ? _value.customHeaders
                : customHeaders // ignore: cast_nullable_to_non_nullable
                      as String?,
            maxTokens: freezed == maxTokens
                ? _value.maxTokens
                : maxTokens // ignore: cast_nullable_to_non_nullable
                      as int?,
            temperature: freezed == temperature
                ? _value.temperature
                : temperature // ignore: cast_nullable_to_non_nullable
                      as double?,
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
abstract class _$$LlmApiSettingsImplCopyWith<$Res>
    implements $LlmApiSettingsCopyWith<$Res> {
  factory _$$LlmApiSettingsImplCopyWith(
    _$LlmApiSettingsImpl value,
    $Res Function(_$LlmApiSettingsImpl) then,
  ) = __$$LlmApiSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String identifier,
    String baseUrl,
    String? customHeaders,
    int? maxTokens,
    double? temperature,
    bool enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$LlmApiSettingsImplCopyWithImpl<$Res>
    extends _$LlmApiSettingsCopyWithImpl<$Res, _$LlmApiSettingsImpl>
    implements _$$LlmApiSettingsImplCopyWith<$Res> {
  __$$LlmApiSettingsImplCopyWithImpl(
    _$LlmApiSettingsImpl _value,
    $Res Function(_$LlmApiSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LlmApiSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? identifier = null,
    Object? baseUrl = null,
    Object? customHeaders = freezed,
    Object? maxTokens = freezed,
    Object? temperature = freezed,
    Object? enabled = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$LlmApiSettingsImpl(
        identifier: null == identifier
            ? _value.identifier
            : identifier // ignore: cast_nullable_to_non_nullable
                  as String,
        baseUrl: null == baseUrl
            ? _value.baseUrl
            : baseUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        customHeaders: freezed == customHeaders
            ? _value.customHeaders
            : customHeaders // ignore: cast_nullable_to_non_nullable
                  as String?,
        maxTokens: freezed == maxTokens
            ? _value.maxTokens
            : maxTokens // ignore: cast_nullable_to_non_nullable
                  as int?,
        temperature: freezed == temperature
            ? _value.temperature
            : temperature // ignore: cast_nullable_to_non_nullable
                  as double?,
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
class _$LlmApiSettingsImpl implements _LlmApiSettings {
  const _$LlmApiSettingsImpl({
    required this.identifier,
    required this.baseUrl,
    this.customHeaders,
    this.maxTokens,
    this.temperature,
    this.enabled = true,
    this.createdAt,
    this.updatedAt,
  });

  factory _$LlmApiSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$LlmApiSettingsImplFromJson(json);

  /// Unique identifier for this LLM configuration (e.g., "gpt-4-turbo", "claude-3-5-sonnet")
  @override
  final String identifier;

  /// Base URL for the API endpoint
  @override
  final String baseUrl;

  /// Optional: Additional headers to include in requests (as JSON string)
  /// Format: {"Header-Name": "value", ...}
  @override
  final String? customHeaders;

  /// Optional: Maximum tokens for this model
  @override
  final int? maxTokens;

  /// Optional: Default temperature setting
  @override
  final double? temperature;

  /// Whether this model is currently enabled
  @override
  @JsonKey()
  final bool enabled;

  /// Creation timestamp
  @override
  final DateTime? createdAt;

  /// Last updated timestamp
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'LlmApiSettings(identifier: $identifier, baseUrl: $baseUrl, customHeaders: $customHeaders, maxTokens: $maxTokens, temperature: $temperature, enabled: $enabled, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LlmApiSettingsImpl &&
            (identical(other.identifier, identifier) ||
                other.identifier == identifier) &&
            (identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl) &&
            (identical(other.customHeaders, customHeaders) ||
                other.customHeaders == customHeaders) &&
            (identical(other.maxTokens, maxTokens) ||
                other.maxTokens == maxTokens) &&
            (identical(other.temperature, temperature) ||
                other.temperature == temperature) &&
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
    identifier,
    baseUrl,
    customHeaders,
    maxTokens,
    temperature,
    enabled,
    createdAt,
    updatedAt,
  );

  /// Create a copy of LlmApiSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LlmApiSettingsImplCopyWith<_$LlmApiSettingsImpl> get copyWith =>
      __$$LlmApiSettingsImplCopyWithImpl<_$LlmApiSettingsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$LlmApiSettingsImplToJson(this);
  }
}

abstract class _LlmApiSettings implements LlmApiSettings {
  const factory _LlmApiSettings({
    required final String identifier,
    required final String baseUrl,
    final String? customHeaders,
    final int? maxTokens,
    final double? temperature,
    final bool enabled,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) = _$LlmApiSettingsImpl;

  factory _LlmApiSettings.fromJson(Map<String, dynamic> json) =
      _$LlmApiSettingsImpl.fromJson;

  /// Unique identifier for this LLM configuration (e.g., "gpt-4-turbo", "claude-3-5-sonnet")
  @override
  String get identifier;

  /// Base URL for the API endpoint
  @override
  String get baseUrl;

  /// Optional: Additional headers to include in requests (as JSON string)
  /// Format: {"Header-Name": "value", ...}
  @override
  String? get customHeaders;

  /// Optional: Maximum tokens for this model
  @override
  int? get maxTokens;

  /// Optional: Default temperature setting
  @override
  double? get temperature;

  /// Whether this model is currently enabled
  @override
  bool get enabled;

  /// Creation timestamp
  @override
  DateTime? get createdAt;

  /// Last updated timestamp
  @override
  DateTime? get updatedAt;

  /// Create a copy of LlmApiSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LlmApiSettingsImplCopyWith<_$LlmApiSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
