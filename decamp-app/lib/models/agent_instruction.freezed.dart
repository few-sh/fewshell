// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_instruction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AgentInstruction _$AgentInstructionFromJson(Map<String, dynamic> json) {
  return _AgentInstruction.fromJson(json);
}

/// @nodoc
mixin _$AgentInstruction {
  /// Default instruction that applies to all models
  String get defaultInstruction => throw _privateConstructorUsedError;

  /// Map of model identifier to model-specific instruction overrides
  /// Key is the LLM identifier (e.g., 'gpt-4', 'claude-3')
  /// Value is the instruction text for that specific model
  Map<String, String> get modelOverrides => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this AgentInstruction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AgentInstruction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AgentInstructionCopyWith<AgentInstruction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AgentInstructionCopyWith<$Res> {
  factory $AgentInstructionCopyWith(
    AgentInstruction value,
    $Res Function(AgentInstruction) then,
  ) = _$AgentInstructionCopyWithImpl<$Res, AgentInstruction>;
  @useResult
  $Res call({
    String defaultInstruction,
    Map<String, String> modelOverrides,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$AgentInstructionCopyWithImpl<$Res, $Val extends AgentInstruction>
    implements $AgentInstructionCopyWith<$Res> {
  _$AgentInstructionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AgentInstruction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? defaultInstruction = null,
    Object? modelOverrides = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            defaultInstruction: null == defaultInstruction
                ? _value.defaultInstruction
                : defaultInstruction // ignore: cast_nullable_to_non_nullable
                      as String,
            modelOverrides: null == modelOverrides
                ? _value.modelOverrides
                : modelOverrides // ignore: cast_nullable_to_non_nullable
                      as Map<String, String>,
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
abstract class _$$AgentInstructionImplCopyWith<$Res>
    implements $AgentInstructionCopyWith<$Res> {
  factory _$$AgentInstructionImplCopyWith(
    _$AgentInstructionImpl value,
    $Res Function(_$AgentInstructionImpl) then,
  ) = __$$AgentInstructionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String defaultInstruction,
    Map<String, String> modelOverrides,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$AgentInstructionImplCopyWithImpl<$Res>
    extends _$AgentInstructionCopyWithImpl<$Res, _$AgentInstructionImpl>
    implements _$$AgentInstructionImplCopyWith<$Res> {
  __$$AgentInstructionImplCopyWithImpl(
    _$AgentInstructionImpl _value,
    $Res Function(_$AgentInstructionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AgentInstruction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? defaultInstruction = null,
    Object? modelOverrides = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$AgentInstructionImpl(
        defaultInstruction: null == defaultInstruction
            ? _value.defaultInstruction
            : defaultInstruction // ignore: cast_nullable_to_non_nullable
                  as String,
        modelOverrides: null == modelOverrides
            ? _value._modelOverrides
            : modelOverrides // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>,
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
class _$AgentInstructionImpl implements _AgentInstruction {
  const _$AgentInstructionImpl({
    this.defaultInstruction = '',
    final Map<String, String> modelOverrides = const {},
    this.createdAt,
    this.updatedAt,
  }) : _modelOverrides = modelOverrides;

  factory _$AgentInstructionImpl.fromJson(Map<String, dynamic> json) =>
      _$$AgentInstructionImplFromJson(json);

  /// Default instruction that applies to all models
  @override
  @JsonKey()
  final String defaultInstruction;

  /// Map of model identifier to model-specific instruction overrides
  /// Key is the LLM identifier (e.g., 'gpt-4', 'claude-3')
  /// Value is the instruction text for that specific model
  final Map<String, String> _modelOverrides;

  /// Map of model identifier to model-specific instruction overrides
  /// Key is the LLM identifier (e.g., 'gpt-4', 'claude-3')
  /// Value is the instruction text for that specific model
  @override
  @JsonKey()
  Map<String, String> get modelOverrides {
    if (_modelOverrides is EqualUnmodifiableMapView) return _modelOverrides;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_modelOverrides);
  }

  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'AgentInstruction(defaultInstruction: $defaultInstruction, modelOverrides: $modelOverrides, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AgentInstructionImpl &&
            (identical(other.defaultInstruction, defaultInstruction) ||
                other.defaultInstruction == defaultInstruction) &&
            const DeepCollectionEquality().equals(
              other._modelOverrides,
              _modelOverrides,
            ) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    defaultInstruction,
    const DeepCollectionEquality().hash(_modelOverrides),
    createdAt,
    updatedAt,
  );

  /// Create a copy of AgentInstruction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AgentInstructionImplCopyWith<_$AgentInstructionImpl> get copyWith =>
      __$$AgentInstructionImplCopyWithImpl<_$AgentInstructionImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AgentInstructionImplToJson(this);
  }
}

abstract class _AgentInstruction implements AgentInstruction {
  const factory _AgentInstruction({
    final String defaultInstruction,
    final Map<String, String> modelOverrides,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) = _$AgentInstructionImpl;

  factory _AgentInstruction.fromJson(Map<String, dynamic> json) =
      _$AgentInstructionImpl.fromJson;

  /// Default instruction that applies to all models
  @override
  String get defaultInstruction;

  /// Map of model identifier to model-specific instruction overrides
  /// Key is the LLM identifier (e.g., 'gpt-4', 'claude-3')
  /// Value is the instruction text for that specific model
  @override
  Map<String, String> get modelOverrides;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of AgentInstruction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AgentInstructionImplCopyWith<_$AgentInstructionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
