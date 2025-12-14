// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TaskStatusImpl _$$TaskStatusImplFromJson(Map<String, dynamic> json) =>
    _$TaskStatusImpl(
      id: _taskStatusIdToString(json['id']),
      status: json['status'] as String,
      bookId: json['bookId'] as String?,
      error: json['error'] as String?,
      progress: (json['progress'] as num?)?.toDouble(),
      currentStep: json['current_step'] as String?,
    );

Map<String, dynamic> _$$TaskStatusImplToJson(_$TaskStatusImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': instance.status,
      'bookId': instance.bookId,
      'error': instance.error,
      'progress': instance.progress,
      'current_step': instance.currentStep,
    };
