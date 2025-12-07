// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ExecutionProgress {
  int get currentCommand => throw _privateConstructorUsedError;
  int get totalCommands => throw _privateConstructorUsedError;
  String get commandName => throw _privateConstructorUsedError;

  /// Create a copy of ExecutionProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExecutionProgressCopyWith<ExecutionProgress> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExecutionProgressCopyWith<$Res> {
  factory $ExecutionProgressCopyWith(
          ExecutionProgress value, $Res Function(ExecutionProgress) then) =
      _$ExecutionProgressCopyWithImpl<$Res, ExecutionProgress>;
  @useResult
  $Res call({int currentCommand, int totalCommands, String commandName});
}

/// @nodoc
class _$ExecutionProgressCopyWithImpl<$Res, $Val extends ExecutionProgress>
    implements $ExecutionProgressCopyWith<$Res> {
  _$ExecutionProgressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExecutionProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentCommand = null,
    Object? totalCommands = null,
    Object? commandName = null,
  }) {
    return _then(_value.copyWith(
      currentCommand: null == currentCommand
          ? _value.currentCommand
          : currentCommand // ignore: cast_nullable_to_non_nullable
              as int,
      totalCommands: null == totalCommands
          ? _value.totalCommands
          : totalCommands // ignore: cast_nullable_to_non_nullable
              as int,
      commandName: null == commandName
          ? _value.commandName
          : commandName // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ExecutionProgressImplCopyWith<$Res>
    implements $ExecutionProgressCopyWith<$Res> {
  factory _$$ExecutionProgressImplCopyWith(_$ExecutionProgressImpl value,
          $Res Function(_$ExecutionProgressImpl) then) =
      __$$ExecutionProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int currentCommand, int totalCommands, String commandName});
}

/// @nodoc
class __$$ExecutionProgressImplCopyWithImpl<$Res>
    extends _$ExecutionProgressCopyWithImpl<$Res, _$ExecutionProgressImpl>
    implements _$$ExecutionProgressImplCopyWith<$Res> {
  __$$ExecutionProgressImplCopyWithImpl(_$ExecutionProgressImpl _value,
      $Res Function(_$ExecutionProgressImpl) _then)
      : super(_value, _then);

  /// Create a copy of ExecutionProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentCommand = null,
    Object? totalCommands = null,
    Object? commandName = null,
  }) {
    return _then(_$ExecutionProgressImpl(
      currentCommand: null == currentCommand
          ? _value.currentCommand
          : currentCommand // ignore: cast_nullable_to_non_nullable
              as int,
      totalCommands: null == totalCommands
          ? _value.totalCommands
          : totalCommands // ignore: cast_nullable_to_non_nullable
              as int,
      commandName: null == commandName
          ? _value.commandName
          : commandName // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$ExecutionProgressImpl implements _ExecutionProgress {
  const _$ExecutionProgressImpl(
      {required this.currentCommand,
      required this.totalCommands,
      required this.commandName});

  @override
  final int currentCommand;
  @override
  final int totalCommands;
  @override
  final String commandName;

  @override
  String toString() {
    return 'ExecutionProgress(currentCommand: $currentCommand, totalCommands: $totalCommands, commandName: $commandName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExecutionProgressImpl &&
            (identical(other.currentCommand, currentCommand) ||
                other.currentCommand == currentCommand) &&
            (identical(other.totalCommands, totalCommands) ||
                other.totalCommands == totalCommands) &&
            (identical(other.commandName, commandName) ||
                other.commandName == commandName));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, currentCommand, totalCommands, commandName);

  /// Create a copy of ExecutionProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExecutionProgressImplCopyWith<_$ExecutionProgressImpl> get copyWith =>
      __$$ExecutionProgressImplCopyWithImpl<_$ExecutionProgressImpl>(
          this, _$identity);
}

abstract class _ExecutionProgress implements ExecutionProgress {
  const factory _ExecutionProgress(
      {required final int currentCommand,
      required final int totalCommands,
      required final String commandName}) = _$ExecutionProgressImpl;

  @override
  int get currentCommand;
  @override
  int get totalCommands;
  @override
  String get commandName;

  /// Create a copy of ExecutionProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExecutionProgressImplCopyWith<_$ExecutionProgressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ChatState {
// Loading state
  bool get isLoading =>
      throw _privateConstructorUsedError; // Execution progress tracking
  ExecutionProgress? get executionProgress =>
      throw _privateConstructorUsedError; // Error state
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatStateCopyWith<ChatState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatStateCopyWith<$Res> {
  factory $ChatStateCopyWith(ChatState value, $Res Function(ChatState) then) =
      _$ChatStateCopyWithImpl<$Res, ChatState>;
  @useResult
  $Res call(
      {bool isLoading, ExecutionProgress? executionProgress, String? error});

  $ExecutionProgressCopyWith<$Res>? get executionProgress;
}

/// @nodoc
class _$ChatStateCopyWithImpl<$Res, $Val extends ChatState>
    implements $ChatStateCopyWith<$Res> {
  _$ChatStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isLoading = null,
    Object? executionProgress = freezed,
    Object? error = freezed,
  }) {
    return _then(_value.copyWith(
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      executionProgress: freezed == executionProgress
          ? _value.executionProgress
          : executionProgress // ignore: cast_nullable_to_non_nullable
              as ExecutionProgress?,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ExecutionProgressCopyWith<$Res>? get executionProgress {
    if (_value.executionProgress == null) {
      return null;
    }

    return $ExecutionProgressCopyWith<$Res>(_value.executionProgress!, (value) {
      return _then(_value.copyWith(executionProgress: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ChatStateImplCopyWith<$Res>
    implements $ChatStateCopyWith<$Res> {
  factory _$$ChatStateImplCopyWith(
          _$ChatStateImpl value, $Res Function(_$ChatStateImpl) then) =
      __$$ChatStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool isLoading, ExecutionProgress? executionProgress, String? error});

  @override
  $ExecutionProgressCopyWith<$Res>? get executionProgress;
}

/// @nodoc
class __$$ChatStateImplCopyWithImpl<$Res>
    extends _$ChatStateCopyWithImpl<$Res, _$ChatStateImpl>
    implements _$$ChatStateImplCopyWith<$Res> {
  __$$ChatStateImplCopyWithImpl(
      _$ChatStateImpl _value, $Res Function(_$ChatStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isLoading = null,
    Object? executionProgress = freezed,
    Object? error = freezed,
  }) {
    return _then(_$ChatStateImpl(
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      executionProgress: freezed == executionProgress
          ? _value.executionProgress
          : executionProgress // ignore: cast_nullable_to_non_nullable
              as ExecutionProgress?,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$ChatStateImpl extends _ChatState {
  const _$ChatStateImpl(
      {this.isLoading = false, this.executionProgress, this.error})
      : super._();

// Loading state
  @override
  @JsonKey()
  final bool isLoading;
// Execution progress tracking
  @override
  final ExecutionProgress? executionProgress;
// Error state
  @override
  final String? error;

  @override
  String toString() {
    return 'ChatState(isLoading: $isLoading, executionProgress: $executionProgress, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatStateImpl &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.executionProgress, executionProgress) ||
                other.executionProgress == executionProgress) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, isLoading, executionProgress, error);

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatStateImplCopyWith<_$ChatStateImpl> get copyWith =>
      __$$ChatStateImplCopyWithImpl<_$ChatStateImpl>(this, _$identity);
}

abstract class _ChatState extends ChatState {
  const factory _ChatState(
      {final bool isLoading,
      final ExecutionProgress? executionProgress,
      final String? error}) = _$ChatStateImpl;
  const _ChatState._() : super._();

// Loading state
  @override
  bool get isLoading; // Execution progress tracking
  @override
  ExecutionProgress? get executionProgress; // Error state
  @override
  String? get error;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatStateImplCopyWith<_$ChatStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
