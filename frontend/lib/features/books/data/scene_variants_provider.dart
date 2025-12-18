import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/scene_variant.dart';

/// Провайдер для хранения вариантов сцен
/// Ключ: sceneId, значение: SceneVariants
final sceneVariantsProvider = StateNotifierProvider<SceneVariantsNotifier, Map<String, SceneVariants>>((ref) {
  return SceneVariantsNotifier();
});

class SceneVariantsNotifier extends StateNotifier<Map<String, SceneVariants>> {
  SceneVariantsNotifier() : super({});

  /// Получить варианты для сцены или создать пустые
  SceneVariants getVariants(String sceneId, {String? originalText, String? originalImageUrl}) {
    if (!state.containsKey(sceneId)) {
      // Создаем начальные варианты с оригинальным текстом/изображением
      final variants = SceneVariants(
        sceneId: sceneId,
        textVariants: originalText != null
            ? [
                TextVariant(
                  id: '${sceneId}_text_0',
                  text: originalText,
                  variantNumber: 0,
                  isSelected: true,
                ),
              ]
            : [],
        imageVariants: originalImageUrl != null
            ? [
                ImageVariant(
                  id: '${sceneId}_image_0',
                  imageUrl: originalImageUrl,
                  variantNumber: 0,
                  isSelected: true,
                ),
              ]
            : [],
        selectedTextVariantId: originalText != null ? '${sceneId}_text_0' : null,
        selectedImageVariantId: originalImageUrl != null ? '${sceneId}_image_0' : null,
      );
      state = {...state, sceneId: variants};
    }
    return state[sceneId]!;
  }

  /// Добавить новый вариант текста
  void addTextVariant(String sceneId, String text, String? instruction) {
    final current = state[sceneId];
    if (current == null) return;
    
    final newVariantNumber = current.textVariants.length;
    if (newVariantNumber >= EditLimits.maxTextEdits) return;
    
    final newVariant = TextVariant(
      id: '${sceneId}_text_$newVariantNumber',
      text: text,
      variantNumber: newVariantNumber,
      instruction: instruction,
      createdAt: DateTime.now().toIso8601String(),
      isSelected: false,
    );
    
    state = {
      ...state,
      sceneId: current.copyWith(
        textVariants: [...current.textVariants, newVariant],
      ),
    };
  }

  /// Добавить новый вариант изображения
  void addImageVariant(String sceneId, String imageUrl, String? instruction) {
    final current = state[sceneId];
    if (current == null) return;
    
    final newVariantNumber = current.imageVariants.length;
    if (newVariantNumber >= EditLimits.maxImageEdits) return;
    
    final newVariant = ImageVariant(
      id: '${sceneId}_image_$newVariantNumber',
      imageUrl: imageUrl,
      variantNumber: newVariantNumber,
      instruction: instruction,
      createdAt: DateTime.now().toIso8601String(),
      isSelected: false,
    );
    
    state = {
      ...state,
      sceneId: current.copyWith(
        imageVariants: [...current.imageVariants, newVariant],
      ),
    };
  }

  /// Выбрать вариант текста
  void selectTextVariant(String sceneId, String variantId) {
    final current = state[sceneId];
    if (current == null) return;
    
    final updatedVariants = current.textVariants.map((v) {
      return v.copyWith(isSelected: v.id == variantId);
    }).toList();
    
    state = {
      ...state,
      sceneId: current.copyWith(
        textVariants: updatedVariants,
        selectedTextVariantId: variantId,
      ),
    };
  }

  /// Выбрать вариант изображения
  void selectImageVariant(String sceneId, String variantId) {
    final current = state[sceneId];
    if (current == null) return;
    
    final updatedVariants = current.imageVariants.map((v) {
      return v.copyWith(isSelected: v.id == variantId);
    }).toList();
    
    state = {
      ...state,
      sceneId: current.copyWith(
        imageVariants: updatedVariants,
        selectedImageVariantId: variantId,
      ),
    };
  }

  /// Получить выбранный текст
  String? getSelectedText(String sceneId) {
    final current = state[sceneId];
    if (current == null) return null;
    
    final selected = current.textVariants.where((v) => v.isSelected).firstOrNull;
    return selected?.text;
  }

  /// Получить выбранное изображение
  String? getSelectedImageUrl(String sceneId) {
    final current = state[sceneId];
    if (current == null) return null;
    
    final selected = current.imageVariants.where((v) => v.isSelected).firstOrNull;
    return selected?.imageUrl;
  }

  /// Проверить, можно ли еще редактировать текст
  bool canEditText(String sceneId) {
    final current = state[sceneId];
    if (current == null) return true;
    return EditLimits.canEditText(current.textVariants.length - 1); // -1 потому что оригинал не считается
  }

  /// Проверить, можно ли еще редактировать изображение
  bool canEditImage(String sceneId) {
    final current = state[sceneId];
    if (current == null) return true;
    return EditLimits.canEditImage(current.imageVariants.length - 1); // -1 потому что оригинал не считается
  }

  /// Получить количество оставшихся попыток текста
  int remainingTextEdits(String sceneId) {
    final current = state[sceneId];
    if (current == null) return EditLimits.maxTextEdits;
    final edits = current.textVariants.length - 1; // Оригинал не считается
    return EditLimits.remainingTextEdits(edits < 0 ? 0 : edits);
  }

  /// Получить количество оставшихся попыток изображения
  int remainingImageEdits(String sceneId) {
    final current = state[sceneId];
    if (current == null) return EditLimits.maxImageEdits;
    final edits = current.imageVariants.length - 1; // Оригинал не считается
    return EditLimits.remainingImageEdits(edits < 0 ? 0 : edits);
  }

  /// Очистить варианты для сцены
  void clearVariants(String sceneId) {
    state = Map.from(state)..remove(sceneId);
  }

  /// Очистить все варианты
  void clearAll() {
    state = {};
  }
}

