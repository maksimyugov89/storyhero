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

TaskProgress _$TaskProgressFromJson(Map<String, dynamic> json) {
  return _TaskProgress.fromJson(json);
}

/// @nodoc
mixin _$TaskProgress {
  String? get stage =>
      throw _privateConstructorUsedError; // "starting", "creating_plot", "plot_ready", etc.
  @JsonKey(name: 'current_step')
  int? get currentStep => throw _privateConstructorUsedError; // номер текущего шага
  @JsonKey(name: 'total_steps')
  int? get totalSteps => throw _privateConstructorUsedError; // общее количество шагов (7)
  String? get message =>
      throw _privateConstructorUsedError; // сообщение для пользователя
  @JsonKey(name: 'book_id')
  String? get bookId => throw _privateConstructorUsedError; // ID книги (когда известен)
  @JsonKey(name: 'images_generated')
  int? get imagesGenerated => throw _privateConstructorUsedError; // количество сгенерированных изображений
  @JsonKey(name: 'total_images')
  int? get totalImages => throw _privateConstructorUsedError;

  /// Serializes this TaskProgress to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TaskProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskProgressCopyWith<TaskProgress> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskProgressCopyWith<$Res> {
  factory $TaskProgressCopyWith(
    TaskProgress value,
    $Res Function(TaskProgress) then,
  ) = _$TaskProgressCopyWithImpl<$Res, TaskProgress>;
  @useResult
  $Res call({
    String? stage,
    @JsonKey(name: 'current_step') int? currentStep,
    @JsonKey(name: 'total_steps') int? totalSteps,
    String? message,
    @JsonKey(name: 'book_id') String? bookId,
    @JsonKey(name: 'images_generated') int? imagesGenerated,
    @JsonKey(name: 'total_images') int? totalImages,
  });
}

/// @nodoc
class _$TaskProgressCopyWithImpl<$Res, $Val extends TaskProgress>
    implements $TaskProgressCopyWith<$Res> {
  _$TaskProgressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? stage = freezed,
    Object? currentStep = freezed,
    Object? totalSteps = freezed,
    Object? message = freezed,
    Object? bookId = freezed,
    Object? imagesGenerated = freezed,
    Object? totalImages = freezed,
  }) {
    return _then(
      _value.copyWith(
            stage: freezed == stage
                ? _value.stage
                : stage // ignore: cast_nullable_to_non_nullable
                      as String?,
            currentStep: freezed == currentStep
                ? _value.currentStep
                : currentStep // ignore: cast_nullable_to_non_nullable
                      as int?,
            totalSteps: freezed == totalSteps
                ? _value.totalSteps
                : totalSteps // ignore: cast_nullable_to_non_nullable
                      as int?,
            message: freezed == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String?,
            bookId: freezed == bookId
                ? _value.bookId
                : bookId // ignore: cast_nullable_to_non_nullable
                      as String?,
            imagesGenerated: freezed == imagesGenerated
                ? _value.imagesGenerated
                : imagesGenerated // ignore: cast_nullable_to_non_nullable
                      as int?,
            totalImages: freezed == totalImages
                ? _value.totalImages
                : totalImages // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TaskProgressImplCopyWith<$Res>
    implements $TaskProgressCopyWith<$Res> {
  factory _$$TaskProgressImplCopyWith(
    _$TaskProgressImpl value,
    $Res Function(_$TaskProgressImpl) then,
  ) = __$$TaskProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? stage,
    @JsonKey(name: 'current_step') int? currentStep,
    @JsonKey(name: 'total_steps') int? totalSteps,
    String? message,
    @JsonKey(name: 'book_id') String? bookId,
    @JsonKey(name: 'images_generated') int? imagesGenerated,
    @JsonKey(name: 'total_images') int? totalImages,
  });
}

/// @nodoc
class __$$TaskProgressImplCopyWithImpl<$Res>
    extends _$TaskProgressCopyWithImpl<$Res, _$TaskProgressImpl>
    implements _$$TaskProgressImplCopyWith<$Res> {
  __$$TaskProgressImplCopyWithImpl(
    _$TaskProgressImpl _value,
    $Res Function(_$TaskProgressImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TaskProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? stage = freezed,
    Object? currentStep = freezed,
    Object? totalSteps = freezed,
    Object? message = freezed,
    Object? bookId = freezed,
    Object? imagesGenerated = freezed,
    Object? totalImages = freezed,
  }) {
    return _then(
      _$TaskProgressImpl(
        stage: freezed == stage
            ? _value.stage
            : stage // ignore: cast_nullable_to_non_nullable
                  as String?,
        currentStep: freezed == currentStep
            ? _value.currentStep
            : currentStep // ignore: cast_nullable_to_non_nullable
                  as int?,
        totalSteps: freezed == totalSteps
            ? _value.totalSteps
            : totalSteps // ignore: cast_nullable_to_non_nullable
                  as int?,
        message: freezed == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String?,
        bookId: freezed == bookId
            ? _value.bookId
            : bookId // ignore: cast_nullable_to_non_nullable
                  as String?,
        imagesGenerated: freezed == imagesGenerated
            ? _value.imagesGenerated
            : imagesGenerated // ignore: cast_nullable_to_non_nullable
                  as int?,
        totalImages: freezed == totalImages
            ? _value.totalImages
            : totalImages // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskProgressImpl implements _TaskProgress {
  const _$TaskProgressImpl({
    this.stage,
    @JsonKey(name: 'current_step') this.currentStep,
    @JsonKey(name: 'total_steps') this.totalSteps,
    this.message,
    @JsonKey(name: 'book_id') this.bookId,
    @JsonKey(name: 'images_generated') this.imagesGenerated,
    @JsonKey(name: 'total_images') this.totalImages,
  });

  factory _$TaskProgressImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskProgressImplFromJson(json);

  @override
  final String? stage;
  // "starting", "creating_plot", "plot_ready", etc.
  @override
  @JsonKey(name: 'current_step')
  final int? currentStep;
  // номер текущего шага
  @override
  @JsonKey(name: 'total_steps')
  final int? totalSteps;
  // общее количество шагов (7)
  @override
  final String? message;
  // сообщение для пользователя
  @override
  @JsonKey(name: 'book_id')
  final String? bookId;
  // ID книги (когда известен)
  @override
  @JsonKey(name: 'images_generated')
  final int? imagesGenerated;
  // количество сгенерированных изображений
  @override
  @JsonKey(name: 'total_images')
  final int? totalImages;

  @override
  String toString() {
    return 'TaskProgress(stage: $stage, currentStep: $currentStep, totalSteps: $totalSteps, message: $message, bookId: $bookId, imagesGenerated: $imagesGenerated, totalImages: $totalImages)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskProgressImpl &&
            (identical(other.stage, stage) || other.stage == stage) &&
            (identical(other.currentStep, currentStep) ||
                other.currentStep == currentStep) &&
            (identical(other.totalSteps, totalSteps) ||
                other.totalSteps == totalSteps) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.bookId, bookId) || other.bookId == bookId) &&
            (identical(other.imagesGenerated, imagesGenerated) ||
                other.imagesGenerated == imagesGenerated) &&
            (identical(other.totalImages, totalImages) ||
                other.totalImages == totalImages));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    stage,
    currentStep,
    totalSteps,
    message,
    bookId,
    imagesGenerated,
    totalImages,
  );

  /// Create a copy of TaskProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskProgressImplCopyWith<_$TaskProgressImpl> get copyWith =>
      __$$TaskProgressImplCopyWithImpl<_$TaskProgressImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskProgressImplToJson(this);
  }
}

abstract class _TaskProgress implements TaskProgress {
  const factory _TaskProgress({
    final String? stage,
    @JsonKey(name: 'current_step') final int? currentStep,
    @JsonKey(name: 'total_steps') final int? totalSteps,
    final String? message,
    @JsonKey(name: 'book_id') final String? bookId,
    @JsonKey(name: 'images_generated') final int? imagesGenerated,
    @JsonKey(name: 'total_images') final int? totalImages,
  }) = _$TaskProgressImpl;

  factory _TaskProgress.fromJson(Map<String, dynamic> json) =
      _$TaskProgressImpl.fromJson;

  @override
  String? get stage; // "starting", "creating_plot", "plot_ready", etc.
  @override
  @JsonKey(name: 'current_step')
  int? get currentStep; // номер текущего шага
  @override
  @JsonKey(name: 'total_steps')
  int? get totalSteps; // общее количество шагов (7)
  @override
  String? get message; // сообщение для пользователя
  @override
  @JsonKey(name: 'book_id')
  String? get bookId; // ID книги (когда известен)
  @override
  @JsonKey(name: 'images_generated')
  int? get imagesGenerated; // количество сгенерированных изображений
  @override
  @JsonKey(name: 'total_images')
  int? get totalImages;

  /// Create a copy of TaskProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskProgressImplCopyWith<_$TaskProgressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TaskStatus _$TaskStatusFromJson(Map<String, dynamic> json) {
  return _TaskStatus.fromJson(json);
}

/// @nodoc
mixin _$TaskStatus {
  @JsonKey(fromJson: _taskStatusIdToString)
  String get id => throw _privateConstructorUsedError;
  String get status =>
      throw _privateConstructorUsedError; // "running", "completed", "failed", "lost", etc.
  @JsonKey(name: 'book_id')
  String? get bookId => throw _privateConstructorUsedError; // для обратной совместимости
  String? get error => throw _privateConstructorUsedError;
  TaskProgress? get progress =>
      throw _privateConstructorUsedError; // объект прогресса согласно API документации
  Map<String, dynamic>? get meta =>
      throw _privateConstructorUsedError; // метаданные, включая book_id при status='lost'
  // Старые поля для обратной совместимости
  @JsonKey(name: 'current_step')
  String? get currentStep => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  double? get progressPercent => throw _privateConstructorUsedError; // вычисляемое поле
  @JsonKey(name: 'created_at')
  String? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'started_at')
  String? get startedAt => throw _privateConstructorUsedError;

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
    @JsonKey(name: 'book_id') String? bookId,
    String? error,
    TaskProgress? progress,
    Map<String, dynamic>? meta,
    @JsonKey(name: 'current_step') String? currentStep,
    @JsonKey(includeFromJson: false, includeToJson: false)
    double? progressPercent,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'started_at') String? startedAt,
  });

  $TaskProgressCopyWith<$Res>? get progress;
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
    Object? meta = freezed,
    Object? currentStep = freezed,
    Object? progressPercent = freezed,
    Object? createdAt = freezed,
    Object? startedAt = freezed,
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
                      as TaskProgress?,
            meta: freezed == meta
                ? _value.meta
                : meta // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            currentStep: freezed == currentStep
                ? _value.currentStep
                : currentStep // ignore: cast_nullable_to_non_nullable
                      as String?,
            progressPercent: freezed == progressPercent
                ? _value.progressPercent
                : progressPercent // ignore: cast_nullable_to_non_nullable
                      as double?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as String?,
            startedAt: freezed == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TaskProgressCopyWith<$Res>? get progress {
    if (_value.progress == null) {
      return null;
    }

    return $TaskProgressCopyWith<$Res>(_value.progress!, (value) {
      return _then(_value.copyWith(progress: value) as $Val);
    });
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
    @JsonKey(name: 'book_id') String? bookId,
    String? error,
    TaskProgress? progress,
    Map<String, dynamic>? meta,
    @JsonKey(name: 'current_step') String? currentStep,
    @JsonKey(includeFromJson: false, includeToJson: false)
    double? progressPercent,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'started_at') String? startedAt,
  });

  @override
  $TaskProgressCopyWith<$Res>? get progress;
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
    Object? meta = freezed,
    Object? currentStep = freezed,
    Object? progressPercent = freezed,
    Object? createdAt = freezed,
    Object? startedAt = freezed,
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
                  as TaskProgress?,
        meta: freezed == meta
            ? _value._meta
            : meta // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        currentStep: freezed == currentStep
            ? _value.currentStep
            : currentStep // ignore: cast_nullable_to_non_nullable
                  as String?,
        progressPercent: freezed == progressPercent
            ? _value.progressPercent
            : progressPercent // ignore: cast_nullable_to_non_nullable
                  as double?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as String?,
        startedAt: freezed == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
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
    @JsonKey(name: 'book_id') this.bookId,
    this.error,
    this.progress,
    final Map<String, dynamic>? meta,
    @JsonKey(name: 'current_step') this.currentStep,
    @JsonKey(includeFromJson: false, includeToJson: false) this.progressPercent,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'started_at') this.startedAt,
  }) : _meta = meta;

  factory _$TaskStatusImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskStatusImplFromJson(json);

  @override
  @JsonKey(fromJson: _taskStatusIdToString)
  final String id;
  @override
  final String status;
  // "running", "completed", "failed", "lost", etc.
  @override
  @JsonKey(name: 'book_id')
  final String? bookId;
  // для обратной совместимости
  @override
  final String? error;
  @override
  final TaskProgress? progress;
  // объект прогресса согласно API документации
  final Map<String, dynamic>? _meta;
  // объект прогресса согласно API документации
  @override
  Map<String, dynamic>? get meta {
    final value = _meta;
    if (value == null) return null;
    if (_meta is EqualUnmodifiableMapView) return _meta;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  // метаданные, включая book_id при status='lost'
  // Старые поля для обратной совместимости
  @override
  @JsonKey(name: 'current_step')
  final String? currentStep;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final double? progressPercent;
  // вычисляемое поле
  @override
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @override
  @JsonKey(name: 'started_at')
  final String? startedAt;

  @override
  String toString() {
    return 'TaskStatus(id: $id, status: $status, bookId: $bookId, error: $error, progress: $progress, meta: $meta, currentStep: $currentStep, progressPercent: $progressPercent, createdAt: $createdAt, startedAt: $startedAt)';
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
            const DeepCollectionEquality().equals(other._meta, _meta) &&
            (identical(other.currentStep, currentStep) ||
                other.currentStep == currentStep) &&
            (identical(other.progressPercent, progressPercent) ||
                other.progressPercent == progressPercent) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt));
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
    const DeepCollectionEquality().hash(_meta),
    currentStep,
    progressPercent,
    createdAt,
    startedAt,
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
    @JsonKey(name: 'book_id') final String? bookId,
    final String? error,
    final TaskProgress? progress,
    final Map<String, dynamic>? meta,
    @JsonKey(name: 'current_step') final String? currentStep,
    @JsonKey(includeFromJson: false, includeToJson: false)
    final double? progressPercent,
    @JsonKey(name: 'created_at') final String? createdAt,
    @JsonKey(name: 'started_at') final String? startedAt,
  }) = _$TaskStatusImpl;

  factory _TaskStatus.fromJson(Map<String, dynamic> json) =
      _$TaskStatusImpl.fromJson;

  @override
  @JsonKey(fromJson: _taskStatusIdToString)
  String get id;
  @override
  String get status; // "running", "completed", "failed", "lost", etc.
  @override
  @JsonKey(name: 'book_id')
  String? get bookId; // для обратной совместимости
  @override
  String? get error;
  @override
  TaskProgress? get progress; // объект прогресса согласно API документации
  @override
  Map<String, dynamic>? get meta; // метаданные, включая book_id при status='lost'
  // Старые поля для обратной совместимости
  @override
  @JsonKey(name: 'current_step')
  String? get currentStep;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  double? get progressPercent; // вычисляемое поле
  @override
  @JsonKey(name: 'created_at')
  String? get createdAt;
  @override
  @JsonKey(name: 'started_at')
  String? get startedAt;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskStatusImplCopyWith<_$TaskStatusImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
