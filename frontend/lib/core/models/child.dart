import 'package:freezed_annotation/freezed_annotation.dart';

part 'child.freezed.dart';
part 'child.g.dart';

@freezed
class Child with _$Child {
  const factory Child({
    @JsonKey(fromJson: _idToString) required String id,
    required String name,
    required int age,
    required String interests,
    required String fears,
    required String character,
    required String moral,
    @JsonKey(name: 'face_url') String? faceUrl,
    @JsonKey(name: 'photos') List<String>? photos,
  }) = _Child;

  factory Child.fromJson(Map<String, dynamic> json) => _$ChildFromJson(json);
}

String _idToString(dynamic value) {
  // Конвертер для преобразования ID из int (PostgreSQL) или String (UUID) в String
  if (value == null) {
    print('[Child] _idToString: ERROR - ID is null');
    throw ArgumentError('ID не может быть null');
  }
  if (value is int) {
    final result = value.toString();
    print('[Child] _idToString: int($value) -> String("$result")');
    return result;
  }
  if (value is String) {
    print('[Child] _idToString: String("$value") -> String("$value")');
    return value;
  }
  // Fallback для других типов (double, num и т.д.)
  final result = value.toString();
  print('[Child] _idToString: ${value.runtimeType}($value) -> String("$result")');
  return result;
}

