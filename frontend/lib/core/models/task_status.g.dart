// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TaskProgressImpl _$$TaskProgressImplFromJson(Map<String, dynamic> json) =>
    _$TaskProgressImpl(
      stage: json['stage'] as String?,
      currentStep: (json['current_step'] as num?)?.toInt(),
      totalSteps: (json['total_steps'] as num?)?.toInt(),
      message: json['message'] as String?,
      bookId: json['book_id'] as String?,
      imagesGenerated: (json['images_generated'] as num?)?.toInt(),
      totalImages: (json['total_images'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$TaskProgressImplToJson(_$TaskProgressImpl instance) =>
    <String, dynamic>{
      'stage': instance.stage,
      'current_step': instance.currentStep,
      'total_steps': instance.totalSteps,
      'message': instance.message,
      'book_id': instance.bookId,
      'images_generated': instance.imagesGenerated,
      'total_images': instance.totalImages,
    };

_$TaskStatusImpl _$$TaskStatusImplFromJson(Map<String, dynamic> json) =>
    _$TaskStatusImpl(
      id: _taskStatusIdToString(json['id']),
      status: json['status'] as String,
      bookId: json['book_id'] as String?,
      error: json['error'] as String?,
      progress: json['progress'] == null
          ? null
          : TaskProgress.fromJson(json['progress'] as Map<String, dynamic>),
      meta: json['meta'] as Map<String, dynamic>?,
      currentStep: json['current_step'] as String?,
      createdAt: json['created_at'] as String?,
      startedAt: json['started_at'] as String?,
    );

Map<String, dynamic> _$$TaskStatusImplToJson(_$TaskStatusImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': instance.status,
      'book_id': instance.bookId,
      'error': instance.error,
      'progress': instance.progress?.toJson(),
      'meta': instance.meta,
      'current_step': instance.currentStep,
      'created_at': instance.createdAt,
      'started_at': instance.startedAt,
    };
