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
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SecretMetadata _$SecretMetadataFromJson(Map<String, dynamic> json) {
  return _SecretMetadata.fromJson(json);
}

/// @nodoc
mixin _$SecretMetadata {
  /// Unique identifier for this secret
  String get id => throw _privateConstructorUsedError;

  /// Project ID (null for global secrets)
  String? get projectId => throw _privateConstructorUsedError;

  /// Human-readable name (e.g., "OpenAI API Key", "SSH Password")
  String get name => throw _privateConstructorUsedError;

  /// Optional description
  String? get description => throw _privateConstructorUsedError;

  /// Creation timestamp
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Last updated timestamp
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this SecretMetadata to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SecretMetadata
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SecretMetadataCopyWith<SecretMetadata> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SecretMetadataCopyWith<$Res> {
  factory $SecretMetadataCopyWith(
          SecretMetadata value, $Res Function(SecretMetadata) then) =
      _$SecretMetadataCopyWithImpl<$Res, SecretMetadata>;
  @useResult
  $Res call(
      {String id,
      String? projectId,
      String name,
      String? description,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class _$SecretMetadataCopyWithImpl<$Res, $Val extends SecretMetadata>
    implements $SecretMetadataCopyWith<$Res> {
  _$SecretMetadataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SecretMetadata
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? projectId = freezed,
    Object? name = null,
    Object? description = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      projectId: freezed == projectId
          ? _value.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String?,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SecretMetadataImplCopyWith<$Res>
    implements $SecretMetadataCopyWith<$Res> {
  factory _$$SecretMetadataImplCopyWith(_$SecretMetadataImpl value,
          $Res Function(_$SecretMetadataImpl) then) =
      __$$SecretMetadataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String? projectId,
      String name,
      String? description,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class __$$SecretMetadataImplCopyWithImpl<$Res>
    extends _$SecretMetadataCopyWithImpl<$Res, _$SecretMetadataImpl>
    implements _$$SecretMetadataImplCopyWith<$Res> {
  __$$SecretMetadataImplCopyWithImpl(
      _$SecretMetadataImpl _value, $Res Function(_$SecretMetadataImpl) _then)
      : super(_value, _then);

  /// Create a copy of SecretMetadata
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? projectId = freezed,
    Object? name = null,
    Object? description = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$SecretMetadataImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      projectId: freezed == projectId
          ? _value.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String?,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SecretMetadataImpl implements _SecretMetadata {
  const _$SecretMetadataImpl(
      {required this.id,
      this.projectId,
      required this.name,
      this.description,
      required this.createdAt,
      required this.updatedAt});

  factory _$SecretMetadataImpl.fromJson(Map<String, dynamic> json) =>
      _$$SecretMetadataImplFromJson(json);

  /// Unique identifier for this secret
  @override
  final String id;

  /// Project ID (null for global secrets)
  @override
  final String? projectId;

  /// Human-readable name (e.g., "OpenAI API Key", "SSH Password")
  @override
  final String name;

  /// Optional description
  @override
  final String? description;

  /// Creation timestamp
  @override
  final DateTime createdAt;

  /// Last updated timestamp
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'SecretMetadata(id: $id, projectId: $projectId, name: $name, description: $description, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SecretMetadataImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            (identical(other.name, name) || other.name == name) &&
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
      runtimeType, id, projectId, name, description, createdAt, updatedAt);

  /// Create a copy of SecretMetadata
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SecretMetadataImplCopyWith<_$SecretMetadataImpl> get copyWith =>
      __$$SecretMetadataImplCopyWithImpl<_$SecretMetadataImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SecretMetadataImplToJson(
      this,
    );
  }
}

abstract class _SecretMetadata implements SecretMetadata {
  const factory _SecretMetadata(
      {required final String id,
      final String? projectId,
      required final String name,
      final String? description,
      required final DateTime createdAt,
      required final DateTime updatedAt}) = _$SecretMetadataImpl;

  factory _SecretMetadata.fromJson(Map<String, dynamic> json) =
      _$SecretMetadataImpl.fromJson;

  /// Unique identifier for this secret
  @override
  String get id;

  /// Project ID (null for global secrets)
  @override
  String? get projectId;

  /// Human-readable name (e.g., "OpenAI API Key", "SSH Password")
  @override
  String get name;

  /// Optional description
  @override
  String? get description;

  /// Creation timestamp
  @override
  DateTime get createdAt;

  /// Last updated timestamp
  @override
  DateTime get updatedAt;

  /// Create a copy of SecretMetadata
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SecretMetadataImplCopyWith<_$SecretMetadataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Secret _$SecretFromJson(Map<String, dynamic> json) {
  return _Secret.fromJson(json);
}

/// @nodoc
mixin _$Secret {
  /// Unique identifier for this secret
  String get id => throw _privateConstructorUsedError;

  /// Project ID (null for global secrets)
  String? get projectId => throw _privateConstructorUsedError;

  /// Human-readable name (e.g., "OpenAI API Key", "SSH Password")
  String get name => throw _privateConstructorUsedError;

  /// Optional description
  String? get description => throw _privateConstructorUsedError;

  /// Creation timestamp
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Last updated timestamp
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// The actual secret value
  String get value => throw _privateConstructorUsedError;

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
  $Res call(
      {String id,
      String? projectId,
      String name,
      String? description,
      DateTime createdAt,
      DateTime updatedAt,
      String value});
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
    Object? name = null,
    Object? description = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? value = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      projectId: freezed == projectId
          ? _value.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String?,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      value: null == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SecretImplCopyWith<$Res> implements $SecretCopyWith<$Res> {
  factory _$$SecretImplCopyWith(
          _$SecretImpl value, $Res Function(_$SecretImpl) then) =
      __$$SecretImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String? projectId,
      String name,
      String? description,
      DateTime createdAt,
      DateTime updatedAt,
      String value});
}

/// @nodoc
class __$$SecretImplCopyWithImpl<$Res>
    extends _$SecretCopyWithImpl<$Res, _$SecretImpl>
    implements _$$SecretImplCopyWith<$Res> {
  __$$SecretImplCopyWithImpl(
      _$SecretImpl _value, $Res Function(_$SecretImpl) _then)
      : super(_value, _then);

  /// Create a copy of Secret
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? projectId = freezed,
    Object? name = null,
    Object? description = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? value = null,
  }) {
    return _then(_$SecretImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      projectId: freezed == projectId
          ? _value.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String?,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      value: null == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SecretImpl extends _Secret {
  const _$SecretImpl(
      {required this.id,
      this.projectId,
      required this.name,
      this.description,
      required this.createdAt,
      required this.updatedAt,
      required this.value})
      : super._();

  factory _$SecretImpl.fromJson(Map<String, dynamic> json) =>
      _$$SecretImplFromJson(json);

  /// Unique identifier for this secret
  @override
  final String id;

  /// Project ID (null for global secrets)
  @override
  final String? projectId;

  /// Human-readable name (e.g., "OpenAI API Key", "SSH Password")
  @override
  final String name;

  /// Optional description
  @override
  final String? description;

  /// Creation timestamp
  @override
  final DateTime createdAt;

  /// Last updated timestamp
  @override
  final DateTime updatedAt;

  /// The actual secret value
  @override
  final String value;

  @override
  String toString() {
    return 'Secret(id: $id, projectId: $projectId, name: $name, description: $description, createdAt: $createdAt, updatedAt: $updatedAt, value: $value)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SecretImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.value, value) || other.value == value));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, projectId, name, description,
      createdAt, updatedAt, value);

  /// Create a copy of Secret
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SecretImplCopyWith<_$SecretImpl> get copyWith =>
      __$$SecretImplCopyWithImpl<_$SecretImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SecretImplToJson(
      this,
    );
  }
}

abstract class _Secret extends Secret {
  const factory _Secret(
      {required final String id,
      final String? projectId,
      required final String name,
      final String? description,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      required final String value}) = _$SecretImpl;
  const _Secret._() : super._();

  factory _Secret.fromJson(Map<String, dynamic> json) = _$SecretImpl.fromJson;

  /// Unique identifier for this secret
  @override
  String get id;

  /// Project ID (null for global secrets)
  @override
  String? get projectId;

  /// Human-readable name (e.g., "OpenAI API Key", "SSH Password")
  @override
  String get name;

  /// Optional description
  @override
  String? get description;

  /// Creation timestamp
  @override
  DateTime get createdAt;

  /// Last updated timestamp
  @override
  DateTime get updatedAt;

  /// The actual secret value
  @override
  String get value;

  /// Create a copy of Secret
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SecretImplCopyWith<_$SecretImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
