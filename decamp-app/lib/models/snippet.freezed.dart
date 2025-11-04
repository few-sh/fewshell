// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'snippet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Snippet _$SnippetFromJson(Map<String, dynamic> json) {
  return _Snippet.fromJson(json);
}

/// @nodoc
mixin _$Snippet {
  String get id => throw _privateConstructorUsedError;
  String? get projectId =>
      throw _privateConstructorUsedError; // null for global snippets
  String get name => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Snippet to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Snippet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SnippetCopyWith<Snippet> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SnippetCopyWith<$Res> {
  factory $SnippetCopyWith(Snippet value, $Res Function(Snippet) then) =
      _$SnippetCopyWithImpl<$Res, Snippet>;
  @useResult
  $Res call({
    String id,
    String? projectId,
    String name,
    String content,
    String? description,
    List<String> tags,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$SnippetCopyWithImpl<$Res, $Val extends Snippet>
    implements $SnippetCopyWith<$Res> {
  _$SnippetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Snippet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? projectId = freezed,
    Object? name = null,
    Object? content = null,
    Object? description = freezed,
    Object? tags = null,
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
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            content: null == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            tags: null == tags
                ? _value.tags
                : tags // ignore: cast_nullable_to_non_nullable
                      as List<String>,
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
abstract class _$$SnippetImplCopyWith<$Res> implements $SnippetCopyWith<$Res> {
  factory _$$SnippetImplCopyWith(
    _$SnippetImpl value,
    $Res Function(_$SnippetImpl) then,
  ) = __$$SnippetImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String? projectId,
    String name,
    String content,
    String? description,
    List<String> tags,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$SnippetImplCopyWithImpl<$Res>
    extends _$SnippetCopyWithImpl<$Res, _$SnippetImpl>
    implements _$$SnippetImplCopyWith<$Res> {
  __$$SnippetImplCopyWithImpl(
    _$SnippetImpl _value,
    $Res Function(_$SnippetImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Snippet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? projectId = freezed,
    Object? name = null,
    Object? content = null,
    Object? description = freezed,
    Object? tags = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$SnippetImpl(
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
        content: null == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        tags: null == tags
            ? _value._tags
            : tags // ignore: cast_nullable_to_non_nullable
                  as List<String>,
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
class _$SnippetImpl implements _Snippet {
  const _$SnippetImpl({
    required this.id,
    this.projectId,
    required this.name,
    required this.content,
    this.description,
    final List<String> tags = const [],
    required this.createdAt,
    required this.updatedAt,
  }) : _tags = tags;

  factory _$SnippetImpl.fromJson(Map<String, dynamic> json) =>
      _$$SnippetImplFromJson(json);

  @override
  final String id;
  @override
  final String? projectId;
  // null for global snippets
  @override
  final String name;
  @override
  final String content;
  @override
  final String? description;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Snippet(id: $id, projectId: $projectId, name: $name, content: $content, description: $description, tags: $tags, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SnippetImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
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
    name,
    content,
    description,
    const DeepCollectionEquality().hash(_tags),
    createdAt,
    updatedAt,
  );

  /// Create a copy of Snippet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SnippetImplCopyWith<_$SnippetImpl> get copyWith =>
      __$$SnippetImplCopyWithImpl<_$SnippetImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SnippetImplToJson(this);
  }
}

abstract class _Snippet implements Snippet {
  const factory _Snippet({
    required final String id,
    final String? projectId,
    required final String name,
    required final String content,
    final String? description,
    final List<String> tags,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$SnippetImpl;

  factory _Snippet.fromJson(Map<String, dynamic> json) = _$SnippetImpl.fromJson;

  @override
  String get id;
  @override
  String? get projectId; // null for global snippets
  @override
  String get name;
  @override
  String get content;
  @override
  String? get description;
  @override
  List<String> get tags;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of Snippet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SnippetImplCopyWith<_$SnippetImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
