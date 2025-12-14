// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TaskStatus _$TaskStatusFromJson(Map<String, dynamic> json) {
  return _TaskStatus.fromJson(json);
}

/// @nodoc
mixin _$TaskStatus {
  @JsonKey(fromJson: _taskStatusIdToString)
  String get id => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String? get bookId => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;
  @JsonKey(name: 'progress')
  double? get progress => throw _privateConstructorUsedError;
  @JsonKey(name: 'current_step')
  String? get currentStep => throw _privateConstructorUsedError;

  /// Serializes this TaskStatus to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskStatusCopyWith<TaskStatus> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskStatusCopyWith<$Res> {
  factory $TaskStatusCopyWith(
    TaskStatus value,
    $Res Function(TaskStatus) then,
  ) = _$TaskStatusCopyWithImpl<$Res, TaskStatus>;
  @useResult
  $Res call({
    @JsonKey(fromJson: _taskStatusIdToString) String id,
    String status,
    String? bookId,
    String? error,
    @JsonKey(name: 'progress') double? progress,
    @JsonKey(name: 'current_step') String? currentStep,
  });
}

/// @nodoc
class _$TaskStatusCopyWithImpl<$Res, $Val extends TaskStatus>
    implements $TaskStatusCopyWith<$Res> {
  _$TaskStatusCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? status = null,
    Object? bookId = freezed,
    Object? error = freezed,
    Object? progress = freezed,
    Object? currentStep = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            bookId: freezed == bookId
                ? _value.bookId
                : bookId // ignore: cast_nullable_to_non_nullable
                      as String?,
            error: freezed == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                      as String?,
            progress: freezed == progress
                ? _value.progress
                : progress // ignore: cast_nullable_to_non_nullable
                      as double?,
            currentStep: freezed == currentStep
                ? _value.currentStep
                : currentStep // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TaskStatusImplCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$$TaskStatusImplCopyWith(
    _$TaskStatusImpl value,
    $Res Function(_$TaskStatusImpl) then,
  ) = __$$TaskStatusImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _taskStatusIdToString) String id,
    String status,
    String? bookId,
    String? error,
    @JsonKey(name: 'progress') double? progress,
    @JsonKey(name: 'current_step') String? currentStep,
  });
}

/// @nodoc
class __$$TaskStatusImplCopyWithImpl<$Res>
    extends _$TaskStatusCopyWithImpl<$Res, _$TaskStatusImpl>
    implements _$$TaskStatusImplCopyWith<$Res> {
  __$$TaskStatusImplCopyWithImpl(
    _$TaskStatusImpl _value,
    $Res Function(_$TaskStatusImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? status = null,
    Object? bookId = freezed,
    Object? error = freezed,
    Object? progress = freezed,
    Object? currentStep = freezed,
  }) {
    return _then(
      _$TaskStatusImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        bookId: freezed == bookId
            ? _value.bookId
            : bookId // ignore: cast_nullable_to_non_nullable
                  as String?,
        error: freezed == error
            ? _value.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        progress: freezed == progress
            ? _value.progress
            : progress // ignore: cast_nullable_to_non_nullable
                  as double?,
        currentStep: freezed == currentStep
            ? _value.currentStep
            : currentStep // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskStatusImpl implements _TaskStatus {
  const _$TaskStatusImpl({
    @JsonKey(fromJson: _taskStatusIdToString) required this.id,
    required this.status,
    this.bookId,
    this.error,
    @JsonKey(name: 'progress') this.progress,
    @JsonKey(name: 'current_step') this.currentStep,
  });

  factory _$TaskStatusImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskStatusImplFromJson(json);

  @override
  @JsonKey(fromJson: _taskStatusIdToString)
  final String id;
  @override
  final String status;
  @override
  final String? bookId;
  @override
  final String? error;
  @override
  @JsonKey(name: 'progress')
  final double? progress;
  @override
  @JsonKey(name: 'current_step')
  final String? currentStep;

  @override
  String toString() {
    return 'TaskStatus(id: $id, status: $status, bookId: $bookId, error: $error, progress: $progress, currentStep: $currentStep)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskStatusImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.bookId, bookId) || other.bookId == bookId) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.currentStep, currentStep) ||
                other.currentStep == currentStep));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    status,
    bookId,
    error,
    progress,
    currentStep,
  );

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskStatusImplCopyWith<_$TaskStatusImpl> get copyWith =>
      __$$TaskStatusImplCopyWithImpl<_$TaskStatusImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskStatusImplToJson(this);
  }
}

abstract class _TaskStatus implements TaskStatus {
  const factory _TaskStatus({
    @JsonKey(fromJson: _taskStatusIdToString) required final String id,
    required final String status,
    final String? bookId,
    final String? error,
    @JsonKey(name: 'progress') final double? progress,
    @JsonKey(name: 'current_step') final String? currentStep,
  }) = _$TaskStatusImpl;

  factory _TaskStatus.fromJson(Map<String, dynamic> json) =
      _$TaskStatusImpl.fromJson;

  @override
  @JsonKey(fromJson: _taskStatusIdToString)
  String get id;
  @override
  String get status;
  @override
  String? get bookId;
  @override
  String? get error;
  @override
  @JsonKey(name: 'progress')
  double? get progress;
  @override
  @JsonKey(name: 'current_step')
  String? get currentStep;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskStatusImplCopyWith<_$TaskStatusImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
