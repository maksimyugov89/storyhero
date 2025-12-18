import 'package:freezed_annotation/freezed_annotation.dart';

part 'scene_variant.freezed.dart';
part 'scene_variant.g.dart';

/// Вариант текста сцены
@freezed
class TextVariant with _$TextVariant {
  const factory TextVariant({
    required String id,
    required String text,
    required int variantNumber,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'instruction') String? instruction, // Инструкция, которая привела к этому варианту
    @Default(false) bool isSelected,
  }) = _TextVariant;

  factory TextVariant.fromJson(Map<String, dynamic> json) => _$TextVariantFromJson(json);
}

/// Вариант изображения сцены
@freezed
class ImageVariant with _$ImageVariant {
  const factory ImageVariant({
    required String id,
    @JsonKey(name: 'image_url') required String imageUrl,
    required int variantNumber,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'instruction') String? instruction, // Инструкция для изменения
    @Default(false) bool isSelected,
  }) = _ImageVariant;

  factory ImageVariant.fromJson(Map<String, dynamic> json) => _$ImageVariantFromJson(json);
}

/// Все варианты для сцены
@freezed
class SceneVariants with _$SceneVariants {
  const factory SceneVariants({
    required String sceneId,
    @Default([]) List<TextVariant> textVariants,
    @Default([]) List<ImageVariant> imageVariants,
    @Default(5) int maxTextVariants,
    @Default(3) int maxImageVariants,
    String? selectedTextVariantId,
    String? selectedImageVariantId,
  }) = _SceneVariants;

  factory SceneVariants.fromJson(Map<String, dynamic> json) => _$SceneVariantsFromJson(json);
}

/// Лимиты редактирования
class EditLimits {
  static const int maxTextEdits = 5;
  static const int maxImageEdits = 3;
  
  static int remainingTextEdits(int currentCount) => maxTextEdits - currentCount;
  static int remainingImageEdits(int currentCount) => maxImageEdits - currentCount;
  
  static bool canEditText(int currentCount) => currentCount < maxTextEdits;
  static bool canEditImage(int currentCount) => currentCount < maxImageEdits;
}

