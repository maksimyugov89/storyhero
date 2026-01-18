import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Кроссплатформенный выбор изображения.
/// На мобильных платформах использует ImagePicker.
/// На Web также использует ImagePicker (который под капотом использует file input).
class PlatformFilePicker {
  static final ImagePicker _picker = ImagePicker();
  
  /// Выбор одного изображения из галереи
  static Future<XFile?> pickImage({
    ImageSource source = ImageSource.gallery,
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
      );
      
      if (image != null) {
        print('[PlatformFilePicker] Выбрано изображение: ${image.name}');
      }
      
      return image;
    } catch (e) {
      print('[PlatformFilePicker] Ошибка выбора изображения: $e');
      return null;
    }
  }
  
  /// Выбор нескольких изображений из галереи
  static Future<List<XFile>> pickMultipleImages({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
      );
      
      print('[PlatformFilePicker] Выбрано ${images.length} изображений');
      
      return images;
    } catch (e) {
      print('[PlatformFilePicker] Ошибка выбора изображений: $e');
      return [];
    }
  }
  
  /// Захват изображения с камеры (только для мобильных)
  static Future<XFile?> captureImage({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    // На Web камера не поддерживается через ImagePicker
    if (kIsWeb) {
      print('[PlatformFilePicker] Камера не поддерживается на Web');
      return null;
    }
    
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
        preferredCameraDevice: preferredCameraDevice,
      );
      
      if (image != null) {
        print('[PlatformFilePicker] Захвачено изображение: ${image.name}');
      }
      
      return image;
    } catch (e) {
      print('[PlatformFilePicker] Ошибка захвата изображения: $e');
      return null;
    }
  }
  
  /// Проверяет, поддерживается ли камера на текущей платформе
  static bool get isCameraSupported => !kIsWeb;
  
  /// Проверяет, работаем ли мы на Web
  static bool get isWeb => kIsWeb;
}
