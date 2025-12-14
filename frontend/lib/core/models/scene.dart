import 'package:freezed_annotation/freezed_annotation.dart';

part 'scene.freezed.dart';
part 'scene.g.dart';

/// Конвертер для преобразования ID из int (PostgreSQL) или String (UUID) в String
String _sceneIdToString(dynamic value) {
  return value.toString();
}

/// Конвертер для short_summary: обрабатывает null и пустые строки
String _shortSummaryFromJson(dynamic value) {
  if (value == null) return '';
  final str = value.toString();
  return str.isEmpty ? '' : str;
}

@freezed
class Scene with _$Scene {
  const factory Scene({
    @JsonKey(fromJson: _sceneIdToString) required String id,
    @JsonKey(name: 'book_id') required String bookId,
    required int order,
    @JsonKey(name: 'short_summary', fromJson: _shortSummaryFromJson) required String shortSummary,
    @JsonKey(name: 'image_prompt') String? imagePrompt, // Сделано опциональным, т.к. API может не возвращать
    @JsonKey(name: 'draft_url') String? draftUrl,
    @JsonKey(name: 'final_url') String? finalUrl,
  }) = _Scene;

  factory Scene.fromJson(Map<String, dynamic> json) => _$SceneFromJson(json);
}

