// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'secret.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Secret {

 String get id; String? get projectId;// null for global secrets
 String get key; String get description; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of Secret
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SecretCopyWith<Secret> get copyWith => _$SecretCopyWithImpl<Secret>(this as Secret, _$identity);

  /// Serializes this Secret to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Secret&&(identical(other.id, id) || other.id == id)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.key, key) || other.key == key)&&(identical(other.description, description) || other.description == description)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,projectId,key,description,createdAt,updatedAt);

@override
String toString() {
  return 'Secret(id: $id, projectId: $projectId, key: $key, description: $description, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $SecretCopyWith<$Res>  {
  factory $SecretCopyWith(Secret value, $Res Function(Secret) _then) = _$SecretCopyWithImpl;
@useResult
$Res call({
 String id, String? projectId, String key, String description, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$SecretCopyWithImpl<$Res>
    implements $SecretCopyWith<$Res> {
  _$SecretCopyWithImpl(this._self, this._then);

  final Secret _self;
  final $Res Function(Secret) _then;

/// Create a copy of Secret
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? projectId = freezed,Object? key = null,Object? description = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Secret].
extension SecretPatterns on Secret {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Secret value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Secret() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Secret value)  $default,){
final _that = this;
switch (_that) {
case _Secret():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Secret value)?  $default,){
final _that = this;
switch (_that) {
case _Secret() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? projectId,  String key,  String description,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Secret() when $default != null:
return $default(_that.id,_that.projectId,_that.key,_that.description,_that.createdAt,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? projectId,  String key,  String description,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Secret():
return $default(_that.id,_that.projectId,_that.key,_that.description,_that.createdAt,_that.updatedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? projectId,  String key,  String description,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Secret() when $default != null:
return $default(_that.id,_that.projectId,_that.key,_that.description,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Secret implements Secret {
  const _Secret({required this.id, this.projectId, required this.key, required this.description, required this.createdAt, required this.updatedAt});
  factory _Secret.fromJson(Map<String, dynamic> json) => _$SecretFromJson(json);

@override final  String id;
@override final  String? projectId;
// null for global secrets
@override final  String key;
@override final  String description;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of Secret
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SecretCopyWith<_Secret> get copyWith => __$SecretCopyWithImpl<_Secret>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SecretToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Secret&&(identical(other.id, id) || other.id == id)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.key, key) || other.key == key)&&(identical(other.description, description) || other.description == description)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,projectId,key,description,createdAt,updatedAt);

@override
String toString() {
  return 'Secret(id: $id, projectId: $projectId, key: $key, description: $description, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$SecretCopyWith<$Res> implements $SecretCopyWith<$Res> {
  factory _$SecretCopyWith(_Secret value, $Res Function(_Secret) _then) = __$SecretCopyWithImpl;
@override @useResult
$Res call({
 String id, String? projectId, String key, String description, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$SecretCopyWithImpl<$Res>
    implements _$SecretCopyWith<$Res> {
  __$SecretCopyWithImpl(this._self, this._then);

  final _Secret _self;
  final $Res Function(_Secret) _then;

/// Create a copy of Secret
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? projectId = freezed,Object? key = null,Object? description = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Secret(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
