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

@freezed
class Book with _$Book {
  const factory Book({
    // обязательные поля
    @JsonKey(fromJson: _bookIdToString) required String id,
    @JsonKey(name: 'child_id', fromJson: _childIdToString) required String childId,
    @JsonKey(name: 'user_id') String? userId,
    required String title,

    @JsonKey(name: 'created_at')
    required DateTime createdAt,

    // статус книги (draft / editing / final)
    @JsonKey(name: 'status')
    @Default('draft')
    String status,

    // необязательные поля
    @JsonKey(name: 'cover_url') String? coverUrl,
    @JsonKey(name: 'final_pdf_url') String? finalPdfUrl,

    @JsonKey(name: 'pages')
    List<dynamic>? pages,

    @JsonKey(name: 'edit_history')
    List<dynamic>? editHistory,

    @JsonKey(name: 'images_final')
    List<dynamic>? imagesFinal,
  }) = _Book;

  factory Book.fromJson(Map<String, dynamic> json) => _$BookFromJson(json);
}
