import 'package:freezed_annotation/freezed_annotation.dart';

part 'child.freezed.dart';
part 'child.g.dart';

/// Пол ребенка
enum ChildGender {
  male,   // мальчик
  female; // девочка

  String get displayName {
    switch (this) {
      case ChildGender.male:
        return 'Мальчик';
      case ChildGender.female:
        return 'Девочка';
    }
  }

  static ChildGender? fromString(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'male':
      case 'мальчик':
      case 'boy':
        return ChildGender.male;
      case 'female':
      case 'девочка':
      case 'girl':
        return ChildGender.female;
      default:
        return null;
    }
  }

  String toApiValue() {
    switch (this) {
      case ChildGender.male:
        return 'male';
      case ChildGender.female:
        return 'female';
    }
  }
}

@freezed
class Child with _$Child {
  const factory Child({
    @JsonKey(fromJson: _idToString) required String id,
    required String name,
    required int age,
    @JsonKey(fromJson: _genderFromJson) @Default(ChildGender.female) ChildGender gender,
    required String interests,
    required String fears,
    required String character,
    required String moral,
    @JsonKey(name: 'face_url') String? faceUrl,
    @JsonKey(name: 'photos', fromJson: _photosFromJson) List<String>? photos,
  }) = _Child;

  factory Child.fromJson(Map<String, dynamic> json) => _$ChildFromJson(json);
}

ChildGender _genderFromJson(dynamic value) {
  if (value == null) {
    // Для обратной совместимости со старыми данными, если поле отсутствует, возвращаем female по умолчанию
    return ChildGender.female;
  }
  final gender = ChildGender.fromString(value.toString());
  if (gender == null) {
    // Если значение некорректное, возвращаем дефолтное значение вместо ошибки
    return ChildGender.female;
  }
  return gender;
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

List<String>? _photosFromJson(dynamic value) {
  if (value == null) {
    return null;
  }
  
  if (value is List) {
    return value.map((e) {
      if (e is String) {
        return e;
      }
      if (e is Map<String, dynamic>) {
        // Backend возвращает массив объектов {url: "...", filename: "...", is_avatar: ...}
        // Извлекаем url из каждого объекта
        final url = e['url'] as String?;
        if (url != null && url.isNotEmpty) {
          return url;
        }
      }
      return e.toString();
    }).where((url) => url.isNotEmpty).toList();
  }
  
  return null;
}

