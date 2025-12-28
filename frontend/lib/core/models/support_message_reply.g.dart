// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'support_message_reply.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SupportMessageReplyImpl _$$SupportMessageReplyImplFromJson(
  Map<String, dynamic> json,
) => _$SupportMessageReplyImpl(
  id: _supportMessageReplyIdToString(json['id']),
  messageId: _messageIdToString(json['message_id']),
  replyText: json['reply_text'] as String,
  repliedBy: json['replied_by'] as String,
  isRead: json['is_read'] as bool? ?? false,
  createdAt: _dateTimeFromJson(json['created_at']),
);

Map<String, dynamic> _$$SupportMessageReplyImplToJson(
  _$SupportMessageReplyImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'message_id': instance.messageId,
  'reply_text': instance.replyText,
  'replied_by': instance.repliedBy,
  'is_read': instance.isRead,
  'created_at': instance.createdAt.toIso8601String(),
};
