import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageCompressor {
  /// Сжимает файл в JPEG ~1024px, 85% качества.
  /// Возвращает новый файл или null при ошибке.
  /// На Web возвращает оригинальный файл без сжатия.
  static Future<File?> compress(File file) async {
    // На Web не сжимаем - flutter_image_compress не работает в браузере
    if (kIsWeb) {
      print('[ImageCompressor] Web platform - returning original file');
      return file;
    }
    
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 85,
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg,
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      print('[ImageCompressor] Ошибка сжатия: $e');
      return null;
    }
  }
  
  /// Сжимает XFile в JPEG ~1024px, 85% качества.
  /// Возвращает новый XFile или null при ошибке.
  /// На Web возвращает оригинальный файл без сжатия.
  static Future<XFile?> compressXFile(XFile imageFile) async {
    // На Web не сжимаем - flutter_image_compress не работает в браузере
    if (kIsWeb) {
      print('[ImageCompressor] Web platform - returning original XFile');
      return imageFile;
    }
    
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        quality: 85,
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg,
      );

      return result != null ? XFile(result.path) : null;
    } catch (e) {
      print('[ImageCompressor] Ошибка сжатия XFile: $e');
      return null;
    }
  }
  
  /// Сжимает байты изображения.
  /// Работает на всех платформах включая Web.
  static Future<Uint8List?> compressBytes(Uint8List bytes, {
    int quality = 85,
    int minWidth = 1024,
    int minHeight = 1024,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
        format: CompressFormat.jpeg,
      );
      return result;
    } catch (e) {
      print('[ImageCompressor] Ошибка сжатия bytes: $e');
      return null;
    }
  }
}
