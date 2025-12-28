// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'support_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SupportMessageImpl _$$SupportMessageImplFromJson(Map<String, dynamic> json) =>
    _$SupportMessageImpl(
      id: _supportMessageIdToString(json['id']),
      userId: json['user_id'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      type: json['type'] as String,
      message: json['message'] as String,
      status: json['status'] as String,
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
      hasUnreadReplies: json['has_unread_replies'] as bool? ?? false,
      repliesCount: (json['replies_count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$SupportMessageImplToJson(
  _$SupportMessageImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'name': instance.name,
  'email': instance.email,
  'type': instance.type,
  'message': instance.message,
  'status': instance.status,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
  'has_unread_replies': instance.hasUnreadReplies,
  'replies_count': instance.repliesCount,
};
