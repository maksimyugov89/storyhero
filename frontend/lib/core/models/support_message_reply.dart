import 'package:freezed_annotation/freezed_annotation.dart';

part 'support_message_reply.freezed.dart';
part 'support_message_reply.g.dart';

/// Конвертер для преобразования ID из int (PostgreSQL) или String (UUID) в String
String _supportMessageReplyIdToString(dynamic value) {
  return value.toString();
}

/// Конвертер для преобразования message_id из int (PostgreSQL) или String (UUID) в String
String _messageIdToString(dynamic value) {
  return value.toString();
}

/// Конвертер для безопасного парсинга даты из JSON
DateTime _dateTimeFromJson(dynamic value) {
  if (value == null) {
    throw ArgumentError('Дата не может быть null');
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      print('[SupportMessageReply] Ошибка парсинга даты: $value, ошибка: $e');
      return DateTime.now();
    }
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }
  print('[SupportMessageReply] Неожиданный тип для даты: ${value.runtimeType}, значение: $value');
  return DateTime.now();
}

@freezed
class SupportMessageReply with _$SupportMessageReply {
  const factory SupportMessageReply({
    @JsonKey(fromJson: _supportMessageReplyIdToString) required String id,
    @JsonKey(name: 'message_id', fromJson: _messageIdToString) required String messageId,
    @JsonKey(name: 'reply_text') required String replyText,
    @JsonKey(name: 'replied_by') required String repliedBy, // 'telegram', 'admin_user_id', 'user_{user_id}'
    @Default(false) @JsonKey(name: 'is_read') bool isRead,
    @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson) required DateTime createdAt,
  }) = _SupportMessageReply;

  factory SupportMessageReply.fromJson(Map<String, dynamic> json) => _$SupportMessageReplyFromJson(json);
}

