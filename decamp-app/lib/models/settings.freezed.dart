// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppSettings {

 bool get darkMode; String get defaultAgentsMd; Map<String, dynamic>? get globalSecrets;
/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppSettingsCopyWith<AppSettings> get copyWith => _$AppSettingsCopyWithImpl<AppSettings>(this as AppSettings, _$identity);

  /// Serializes this AppSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppSettings&&(identical(other.darkMode, darkMode) || other.darkMode == darkMode)&&(identical(other.defaultAgentsMd, defaultAgentsMd) || other.defaultAgentsMd == defaultAgentsMd)&&const DeepCollectionEquality().equals(other.globalSecrets, globalSecrets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,darkMode,defaultAgentsMd,const DeepCollectionEquality().hash(globalSecrets));

@override
String toString() {
  return 'AppSettings(darkMode: $darkMode, defaultAgentsMd: $defaultAgentsMd, globalSecrets: $globalSecrets)';
}


}

/// @nodoc
abstract mixin class $AppSettingsCopyWith<$Res>  {
  factory $AppSettingsCopyWith(AppSettings value, $Res Function(AppSettings) _then) = _$AppSettingsCopyWithImpl;
@useResult
$Res call({
 bool darkMode, String defaultAgentsMd, Map<String, dynamic>? globalSecrets
});




}
/// @nodoc
class _$AppSettingsCopyWithImpl<$Res>
    implements $AppSettingsCopyWith<$Res> {
  _$AppSettingsCopyWithImpl(this._self, this._then);

  final AppSettings _self;
  final $Res Function(AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? darkMode = null,Object? defaultAgentsMd = null,Object? globalSecrets = freezed,}) {
  return _then(_self.copyWith(
darkMode: null == darkMode ? _self.darkMode : darkMode // ignore: cast_nullable_to_non_nullable
as bool,defaultAgentsMd: null == defaultAgentsMd ? _self.defaultAgentsMd : defaultAgentsMd // ignore: cast_nullable_to_non_nullable
as String,globalSecrets: freezed == globalSecrets ? _self.globalSecrets : globalSecrets // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

}


/// Adds pattern-matching-related methods to [AppSettings].
extension AppSettingsPatterns on AppSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppSettings value)  $default,){
final _that = this;
switch (_that) {
case _AppSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppSettings value)?  $default,){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool darkMode,  String defaultAgentsMd,  Map<String, dynamic>? globalSecrets)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.darkMode,_that.defaultAgentsMd,_that.globalSecrets);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool darkMode,  String defaultAgentsMd,  Map<String, dynamic>? globalSecrets)  $default,) {final _that = this;
switch (_that) {
case _AppSettings():
return $default(_that.darkMode,_that.defaultAgentsMd,_that.globalSecrets);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool darkMode,  String defaultAgentsMd,  Map<String, dynamic>? globalSecrets)?  $default,) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.darkMode,_that.defaultAgentsMd,_that.globalSecrets);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppSettings implements AppSettings {
  const _AppSettings({this.darkMode = false, this.defaultAgentsMd = '', final  Map<String, dynamic>? globalSecrets}): _globalSecrets = globalSecrets;
  factory _AppSettings.fromJson(Map<String, dynamic> json) => _$AppSettingsFromJson(json);

@override@JsonKey() final  bool darkMode;
@override@JsonKey() final  String defaultAgentsMd;
 final  Map<String, dynamic>? _globalSecrets;
@override Map<String, dynamic>? get globalSecrets {
  final value = _globalSecrets;
  if (value == null) return null;
  if (_globalSecrets is EqualUnmodifiableMapView) return _globalSecrets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppSettingsCopyWith<_AppSettings> get copyWith => __$AppSettingsCopyWithImpl<_AppSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppSettings&&(identical(other.darkMode, darkMode) || other.darkMode == darkMode)&&(identical(other.defaultAgentsMd, defaultAgentsMd) || other.defaultAgentsMd == defaultAgentsMd)&&const DeepCollectionEquality().equals(other._globalSecrets, _globalSecrets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,darkMode,defaultAgentsMd,const DeepCollectionEquality().hash(_globalSecrets));

@override
String toString() {
  return 'AppSettings(darkMode: $darkMode, defaultAgentsMd: $defaultAgentsMd, globalSecrets: $globalSecrets)';
}


}

/// @nodoc
abstract mixin class _$AppSettingsCopyWith<$Res> implements $AppSettingsCopyWith<$Res> {
  factory _$AppSettingsCopyWith(_AppSettings value, $Res Function(_AppSettings) _then) = __$AppSettingsCopyWithImpl;
@override @useResult
$Res call({
 bool darkMode, String defaultAgentsMd, Map<String, dynamic>? globalSecrets
});




}
/// @nodoc
class __$AppSettingsCopyWithImpl<$Res>
    implements _$AppSettingsCopyWith<$Res> {
  __$AppSettingsCopyWithImpl(this._self, this._then);

  final _AppSettings _self;
  final $Res Function(_AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? darkMode = null,Object? defaultAgentsMd = null,Object? globalSecrets = freezed,}) {
  return _then(_AppSettings(
darkMode: null == darkMode ? _self.darkMode : darkMode // ignore: cast_nullable_to_non_nullable
as bool,defaultAgentsMd: null == defaultAgentsMd ? _self.defaultAgentsMd : defaultAgentsMd // ignore: cast_nullable_to_non_nullable
as String,globalSecrets: freezed == globalSecrets ? _self._globalSecrets : globalSecrets // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}


}


/// @nodoc
mixin _$ProjectSettings {

 String get projectId; String? get agentsMd; String? get githubRepo; String? get githubBranch; Map<String, String>? get secrets; bool get enableGithubSync; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of ProjectSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectSettingsCopyWith<ProjectSettings> get copyWith => _$ProjectSettingsCopyWithImpl<ProjectSettings>(this as ProjectSettings, _$identity);

  /// Serializes this ProjectSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectSettings&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.agentsMd, agentsMd) || other.agentsMd == agentsMd)&&(identical(other.githubRepo, githubRepo) || other.githubRepo == githubRepo)&&(identical(other.githubBranch, githubBranch) || other.githubBranch == githubBranch)&&const DeepCollectionEquality().equals(other.secrets, secrets)&&(identical(other.enableGithubSync, enableGithubSync) || other.enableGithubSync == enableGithubSync)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectId,agentsMd,githubRepo,githubBranch,const DeepCollectionEquality().hash(secrets),enableGithubSync,createdAt,updatedAt);

@override
String toString() {
  return 'ProjectSettings(projectId: $projectId, agentsMd: $agentsMd, githubRepo: $githubRepo, githubBranch: $githubBranch, secrets: $secrets, enableGithubSync: $enableGithubSync, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ProjectSettingsCopyWith<$Res>  {
  factory $ProjectSettingsCopyWith(ProjectSettings value, $Res Function(ProjectSettings) _then) = _$ProjectSettingsCopyWithImpl;
@useResult
$Res call({
 String projectId, String? agentsMd, String? githubRepo, String? githubBranch, Map<String, String>? secrets, bool enableGithubSync, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$ProjectSettingsCopyWithImpl<$Res>
    implements $ProjectSettingsCopyWith<$Res> {
  _$ProjectSettingsCopyWithImpl(this._self, this._then);

  final ProjectSettings _self;
  final $Res Function(ProjectSettings) _then;

/// Create a copy of ProjectSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projectId = null,Object? agentsMd = freezed,Object? githubRepo = freezed,Object? githubBranch = freezed,Object? secrets = freezed,Object? enableGithubSync = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,agentsMd: freezed == agentsMd ? _self.agentsMd : agentsMd // ignore: cast_nullable_to_non_nullable
as String?,githubRepo: freezed == githubRepo ? _self.githubRepo : githubRepo // ignore: cast_nullable_to_non_nullable
as String?,githubBranch: freezed == githubBranch ? _self.githubBranch : githubBranch // ignore: cast_nullable_to_non_nullable
as String?,secrets: freezed == secrets ? _self.secrets : secrets // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,enableGithubSync: null == enableGithubSync ? _self.enableGithubSync : enableGithubSync // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProjectSettings].
extension ProjectSettingsPatterns on ProjectSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectSettings value)  $default,){
final _that = this;
switch (_that) {
case _ProjectSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectSettings value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String projectId,  String? agentsMd,  String? githubRepo,  String? githubBranch,  Map<String, String>? secrets,  bool enableGithubSync,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectSettings() when $default != null:
return $default(_that.projectId,_that.agentsMd,_that.githubRepo,_that.githubBranch,_that.secrets,_that.enableGithubSync,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String projectId,  String? agentsMd,  String? githubRepo,  String? githubBranch,  Map<String, String>? secrets,  bool enableGithubSync,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ProjectSettings():
return $default(_that.projectId,_that.agentsMd,_that.githubRepo,_that.githubBranch,_that.secrets,_that.enableGithubSync,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String projectId,  String? agentsMd,  String? githubRepo,  String? githubBranch,  Map<String, String>? secrets,  bool enableGithubSync,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ProjectSettings() when $default != null:
return $default(_that.projectId,_that.agentsMd,_that.githubRepo,_that.githubBranch,_that.secrets,_that.enableGithubSync,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProjectSettings implements ProjectSettings {
  const _ProjectSettings({required this.projectId, this.agentsMd, this.githubRepo, this.githubBranch, final  Map<String, String>? secrets, this.enableGithubSync = true, this.createdAt, this.updatedAt}): _secrets = secrets;
  factory _ProjectSettings.fromJson(Map<String, dynamic> json) => _$ProjectSettingsFromJson(json);

@override final  String projectId;
@override final  String? agentsMd;
@override final  String? githubRepo;
@override final  String? githubBranch;
 final  Map<String, String>? _secrets;
@override Map<String, String>? get secrets {
  final value = _secrets;
  if (value == null) return null;
  if (_secrets is EqualUnmodifiableMapView) return _secrets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey() final  bool enableGithubSync;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of ProjectSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectSettingsCopyWith<_ProjectSettings> get copyWith => __$ProjectSettingsCopyWithImpl<_ProjectSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectSettings&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.agentsMd, agentsMd) || other.agentsMd == agentsMd)&&(identical(other.githubRepo, githubRepo) || other.githubRepo == githubRepo)&&(identical(other.githubBranch, githubBranch) || other.githubBranch == githubBranch)&&const DeepCollectionEquality().equals(other._secrets, _secrets)&&(identical(other.enableGithubSync, enableGithubSync) || other.enableGithubSync == enableGithubSync)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectId,agentsMd,githubRepo,githubBranch,const DeepCollectionEquality().hash(_secrets),enableGithubSync,createdAt,updatedAt);

@override
String toString() {
  return 'ProjectSettings(projectId: $projectId, agentsMd: $agentsMd, githubRepo: $githubRepo, githubBranch: $githubBranch, secrets: $secrets, enableGithubSync: $enableGithubSync, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ProjectSettingsCopyWith<$Res> implements $ProjectSettingsCopyWith<$Res> {
  factory _$ProjectSettingsCopyWith(_ProjectSettings value, $Res Function(_ProjectSettings) _then) = __$ProjectSettingsCopyWithImpl;
@override @useResult
$Res call({
 String projectId, String? agentsMd, String? githubRepo, String? githubBranch, Map<String, String>? secrets, bool enableGithubSync, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$ProjectSettingsCopyWithImpl<$Res>
    implements _$ProjectSettingsCopyWith<$Res> {
  __$ProjectSettingsCopyWithImpl(this._self, this._then);

  final _ProjectSettings _self;
  final $Res Function(_ProjectSettings) _then;

/// Create a copy of ProjectSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectId = null,Object? agentsMd = freezed,Object? githubRepo = freezed,Object? githubBranch = freezed,Object? secrets = freezed,Object? enableGithubSync = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_ProjectSettings(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,agentsMd: freezed == agentsMd ? _self.agentsMd : agentsMd // ignore: cast_nullable_to_non_nullable
as String?,githubRepo: freezed == githubRepo ? _self.githubRepo : githubRepo // ignore: cast_nullable_to_non_nullable
as String?,githubBranch: freezed == githubBranch ? _self.githubBranch : githubBranch // ignore: cast_nullable_to_non_nullable
as String?,secrets: freezed == secrets ? _self._secrets : secrets // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,enableGithubSync: null == enableGithubSync ? _self.enableGithubSync : enableGithubSync // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
