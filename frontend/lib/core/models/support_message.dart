import 'package:freezed_annotation/freezed_annotation.dart';

part 'support_message.freezed.dart';
part 'support_message.g.dart';

/// Конвертер для преобразования ID из int (PostgreSQL) или String (UUID) в String
String _supportMessageIdToString(dynamic value) {
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
      print('[SupportMessage] Ошибка парсинга даты: $value, ошибка: $e');
      return DateTime.now();
    }
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }
  print('[SupportMessage] Неожиданный тип для даты: ${value.runtimeType}, значение: $value');
  return DateTime.now();
}

@freezed
class SupportMessage with _$SupportMessage {
  const factory SupportMessage({
    @JsonKey(fromJson: _supportMessageIdToString) required String id,
    @JsonKey(name: 'user_id') String? userId,
    String? name,
    String? email,
    required String type, // 'suggestion', 'bug', 'question'
    required String message,
    required String status, // 'new', 'answered', 'closed'
    @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson) required DateTime createdAt,
    @JsonKey(name: 'updated_at', fromJson: _dateTimeFromJson) required DateTime updatedAt,
    @Default(false) @JsonKey(name: 'has_unread_replies') bool hasUnreadReplies,
    @Default(0) @JsonKey(name: 'replies_count') int repliesCount,
  }) = _SupportMessage;

  factory SupportMessage.fromJson(Map<String, dynamic> json) => _$SupportMessageFromJson(json);
}

