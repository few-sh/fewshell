// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'secret.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Secret _$SecretFromJson(Map<String, dynamic> json) {
  return _Secret.fromJson(json);
}

/// @nodoc
mixin _$Secret {
  String get id => throw _privateConstructorUsedError;
  String? get projectId =>
      throw _privateConstructorUsedError; // null for global secrets
  String get key => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Secret to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Secret
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SecretCopyWith<Secret> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SecretCopyWith<$Res> {
  factory $SecretCopyWith(Secret value, $Res Function(Secret) then) =
      _$SecretCopyWithImpl<$Res, Secret>;
  @useResult
  $Res call({
    String id,
    String? projectId,
    String key,
    String description,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$SecretCopyWithImpl<$Res, $Val extends Secret>
    implements $SecretCopyWith<$Res> {
  _$SecretCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Secret
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? projectId = freezed,
    Object? key = null,
    Object? description = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            projectId: freezed == projectId
                ? _value.projectId
                : projectId // ignore: cast_nullable_to_non_nullable
                      as String?,
            key: null == key
                ? _value.key
                : key // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SecretImplCopyWith<$Res> implements $SecretCopyWith<$Res> {
  factory _$$SecretImplCopyWith(
    _$SecretImpl value,
    $Res Function(_$SecretImpl) then,
  ) = __$$SecretImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String? projectId,
    String key,
    String description,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$SecretImplCopyWithImpl<$Res>
    extends _$SecretCopyWithImpl<$Res, _$SecretImpl>
    implements _$$SecretImplCopyWith<$Res> {
  __$$SecretImplCopyWithImpl(
    _$SecretImpl _value,
    $Res Function(_$SecretImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Secret
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? projectId = freezed,
    Object? key = null,
    Object? description = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$SecretImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        projectId: freezed == projectId
            ? _value.projectId
            : projectId // ignore: cast_nullable_to_non_nullable
                  as String?,
        key: null == key
            ? _value.key
            : key // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SecretImpl implements _Secret {
  const _$SecretImpl({
    required this.id,
    this.projectId,
    required this.key,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _$SecretImpl.fromJson(Map<String, dynamic> json) =>
      _$$SecretImplFromJson(json);

  @override
  final String id;
  @override
  final String? projectId;
  // null for global secrets
  @override
  final String key;
  @override
  final String description;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Secret(id: $id, projectId: $projectId, key: $key, description: $description, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SecretImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            (identical(other.key, key) || other.key == key) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    projectId,
    key,
    description,
    createdAt,
    updatedAt,
  );

  /// Create a copy of Secret
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SecretImplCopyWith<_$SecretImpl> get copyWith =>
      __$$SecretImplCopyWithImpl<_$SecretImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SecretImplToJson(this);
  }
}

abstract class _Secret implements Secret {
  const factory _Secret({
    required final String id,
    final String? projectId,
    required final String key,
    required final String description,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$SecretImpl;

  factory _Secret.fromJson(Map<String, dynamic> json) = _$SecretImpl.fromJson;

  @override
  String get id;
  @override
  String? get projectId; // null for global secrets
  @override
  String get key;
  @override
  String get description;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of Secret
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SecretImplCopyWith<_$SecretImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
