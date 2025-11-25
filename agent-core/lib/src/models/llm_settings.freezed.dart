// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'llm_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

LlmSettings _$LlmSettingsFromJson(Map<String, dynamic> json) {
  return _LlmSettings.fromJson(json);
}

/// @nodoc
mixin _$LlmSettings {
  /// Unique identifier for this LLM configuration (e.g., "gpt-4-turbo")
  String get identifier => throw _privateConstructorUsedError;

  /// Type of API provider (openai, anthropic, google, etc.)
  String get provider => throw _privateConstructorUsedError;

  /// Model identifier (e.g., "gpt-4o", "claude-3-5-sonnet")
  String get model => throw _privateConstructorUsedError;

  /// Base URL for the API endpoint
  String get baseUrl => throw _privateConstructorUsedError;

  /// Secret ID that references the API key (not the actual key)
  String? get apiKeySecretId => throw _privateConstructorUsedError;

  /// Optional: Maximum tokens for this model
  int? get maxTokens => throw _privateConstructorUsedError;

  /// Optional: Default temperature setting
  double? get temperature => throw _privateConstructorUsedError;

  /// Whether this configuration is enabled
  bool get enabled => throw _privateConstructorUsedError;

  /// Serializes this LlmSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LlmSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LlmSettingsCopyWith<LlmSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LlmSettingsCopyWith<$Res> {
  factory $LlmSettingsCopyWith(
          LlmSettings value, $Res Function(LlmSettings) then) =
      _$LlmSettingsCopyWithImpl<$Res, LlmSettings>;
  @useResult
  $Res call(
      {String identifier,
      String provider,
      String model,
      String baseUrl,
      String? apiKeySecretId,
      int? maxTokens,
      double? temperature,
      bool enabled});
}

/// @nodoc
class _$LlmSettingsCopyWithImpl<$Res, $Val extends LlmSettings>
    implements $LlmSettingsCopyWith<$Res> {
  _$LlmSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LlmSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? identifier = null,
    Object? provider = null,
    Object? model = null,
    Object? baseUrl = null,
    Object? apiKeySecretId = freezed,
    Object? maxTokens = freezed,
    Object? temperature = freezed,
    Object? enabled = null,
  }) {
    return _then(_value.copyWith(
      identifier: null == identifier
          ? _value.identifier
          : identifier // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _value.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      model: null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      baseUrl: null == baseUrl
          ? _value.baseUrl
          : baseUrl // ignore: cast_nullable_to_non_nullable
              as String,
      apiKeySecretId: freezed == apiKeySecretId
          ? _value.apiKeySecretId
          : apiKeySecretId // ignore: cast_nullable_to_non_nullable
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
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LlmSettingsImplCopyWith<$Res>
    implements $LlmSettingsCopyWith<$Res> {
  factory _$$LlmSettingsImplCopyWith(
          _$LlmSettingsImpl value, $Res Function(_$LlmSettingsImpl) then) =
      __$$LlmSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String identifier,
      String provider,
      String model,
      String baseUrl,
      String? apiKeySecretId,
      int? maxTokens,
      double? temperature,
      bool enabled});
}

/// @nodoc
class __$$LlmSettingsImplCopyWithImpl<$Res>
    extends _$LlmSettingsCopyWithImpl<$Res, _$LlmSettingsImpl>
    implements _$$LlmSettingsImplCopyWith<$Res> {
  __$$LlmSettingsImplCopyWithImpl(
      _$LlmSettingsImpl _value, $Res Function(_$LlmSettingsImpl) _then)
      : super(_value, _then);

  /// Create a copy of LlmSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? identifier = null,
    Object? provider = null,
    Object? model = null,
    Object? baseUrl = null,
    Object? apiKeySecretId = freezed,
    Object? maxTokens = freezed,
    Object? temperature = freezed,
    Object? enabled = null,
  }) {
    return _then(_$LlmSettingsImpl(
      identifier: null == identifier
          ? _value.identifier
          : identifier // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _value.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      model: null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      baseUrl: null == baseUrl
          ? _value.baseUrl
          : baseUrl // ignore: cast_nullable_to_non_nullable
              as String,
      apiKeySecretId: freezed == apiKeySecretId
          ? _value.apiKeySecretId
          : apiKeySecretId // ignore: cast_nullable_to_non_nullable
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
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$LlmSettingsImpl implements _LlmSettings {
  const _$LlmSettingsImpl(
      {required this.identifier,
      required this.provider,
      required this.model,
      required this.baseUrl,
      this.apiKeySecretId,
      this.maxTokens,
      this.temperature,
      this.enabled = true});

  factory _$LlmSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$LlmSettingsImplFromJson(json);

  /// Unique identifier for this LLM configuration (e.g., "gpt-4-turbo")
  @override
  final String identifier;

  /// Type of API provider (openai, anthropic, google, etc.)
  @override
  final String provider;

  /// Model identifier (e.g., "gpt-4o", "claude-3-5-sonnet")
  @override
  final String model;

  /// Base URL for the API endpoint
  @override
  final String baseUrl;

  /// Secret ID that references the API key (not the actual key)
  @override
  final String? apiKeySecretId;

  /// Optional: Maximum tokens for this model
  @override
  final int? maxTokens;

  /// Optional: Default temperature setting
  @override
  final double? temperature;

  /// Whether this configuration is enabled
  @override
  @JsonKey()
  final bool enabled;

  @override
  String toString() {
    return 'LlmSettings(identifier: $identifier, provider: $provider, model: $model, baseUrl: $baseUrl, apiKeySecretId: $apiKeySecretId, maxTokens: $maxTokens, temperature: $temperature, enabled: $enabled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LlmSettingsImpl &&
            (identical(other.identifier, identifier) ||
                other.identifier == identifier) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl) &&
            (identical(other.apiKeySecretId, apiKeySecretId) ||
                other.apiKeySecretId == apiKeySecretId) &&
            (identical(other.maxTokens, maxTokens) ||
                other.maxTokens == maxTokens) &&
            (identical(other.temperature, temperature) ||
                other.temperature == temperature) &&
            (identical(other.enabled, enabled) || other.enabled == enabled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, identifier, provider, model,
      baseUrl, apiKeySecretId, maxTokens, temperature, enabled);

  /// Create a copy of LlmSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LlmSettingsImplCopyWith<_$LlmSettingsImpl> get copyWith =>
      __$$LlmSettingsImplCopyWithImpl<_$LlmSettingsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LlmSettingsImplToJson(
      this,
    );
  }
}

abstract class _LlmSettings implements LlmSettings {
  const factory _LlmSettings(
      {required final String identifier,
      required final String provider,
      required final String model,
      required final String baseUrl,
      final String? apiKeySecretId,
      final int? maxTokens,
      final double? temperature,
      final bool enabled}) = _$LlmSettingsImpl;

  factory _LlmSettings.fromJson(Map<String, dynamic> json) =
      _$LlmSettingsImpl.fromJson;

  /// Unique identifier for this LLM configuration (e.g., "gpt-4-turbo")
  @override
  String get identifier;

  /// Type of API provider (openai, anthropic, google, etc.)
  @override
  String get provider;

  /// Model identifier (e.g., "gpt-4o", "claude-3-5-sonnet")
  @override
  String get model;

  /// Base URL for the API endpoint
  @override
  String get baseUrl;

  /// Secret ID that references the API key (not the actual key)
  @override
  String? get apiKeySecretId;

  /// Optional: Maximum tokens for this model
  @override
  int? get maxTokens;

  /// Optional: Default temperature setting
  @override
  double? get temperature;

  /// Whether this configuration is enabled
  @override
  bool get enabled;

  /// Create a copy of LlmSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LlmSettingsImplCopyWith<_$LlmSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
