import 'package:freezed_annotation/freezed_annotation.dart';

part 'book.freezed.dart';
part 'book.g.dart';

/// Конвертер для преобразования ID из int (PostgreSQL) или String (UUID) в String
String _bookIdToString(dynamic value) {
  return value.toString();
}

/// Конвертер для преобразования child_id из int (PostgreSQL) или String (UUID) в String
String _childIdToString(dynamic value) {
  if (value == null) {
    throw ArgumentError('child_id не может быть null');
  }
  if (value is int) {
    return value.toString();
  }
  if (value is String) {
    return value;
  }
  return value.toString();
}

/// Конвертер для безопасного парсинга даты из JSON
DateTime _dateTimeFromJson(dynamic value) {
  if (value == null) {
    throw ArgumentError('created_at не может быть null');
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      print('[Book] Ошибка парсинга даты: $value, ошибка: $e');
      // Если не удалось распарсить, возвращаем текущую дату
      return DateTime.now();
    }
  }
  if (value is int) {
    // Unix timestamp в секундах
    return DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }
  print('[Book] Неожиданный тип для created_at: ${value.runtimeType}, значение: $value');
  return DateTime.now();
}

@freezed
class Book with _$Book {
  const factory Book({
    // обязательные поля
    @JsonKey(fromJson: _bookIdToString) required String id,
    @JsonKey(name: 'child_id', fromJson: _childIdToString) required String childId,
    @JsonKey(name: 'user_id') String? userId,
    required String title,

    @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
    required DateTime createdAt,

    // статус книги (draft / editing / final)
    @JsonKey(name: 'status')
    @Default('draft')
    String status,

    // необязательные поля
    @JsonKey(name: 'cover_url') String? coverUrl,
    @JsonKey(name: 'final_pdf_url') String? finalPdfUrl,
    
    // Статус оплаты книги
    @JsonKey(name: 'is_paid') @Default(false) bool isPaid,

    @JsonKey(name: 'pages')
    List<dynamic>? pages,

    @JsonKey(name: 'edit_history')
    List<dynamic>? editHistory,

    @JsonKey(name: 'images_final')
    List<dynamic>? imagesFinal,
  }) = _Book;

  factory Book.fromJson(Map<String, dynamic> json) => _$BookFromJson(json);
}
