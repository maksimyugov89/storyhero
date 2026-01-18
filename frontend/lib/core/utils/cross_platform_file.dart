import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Кроссплатформенный класс для работы с файлами.
/// На мобильных платформах оборачивает dart:io.File.
/// На Web работает с bytes напрямую через XFile.
class CrossPlatformFile {
  final String name;
  final String? path;
  final Uint8List? _bytes;
  final XFile? _xFile;
  
  CrossPlatformFile._({
    required this.name,
    this.path,
    Uint8List? bytes,
    XFile? xFile,
  }) : _bytes = bytes,
       _xFile = xFile;
  
  /// Создает из XFile (работает на всех платформах)
  static CrossPlatformFile fromXFile(XFile xFile) {
    return CrossPlatformFile._(
      name: xFile.name,
      path: kIsWeb ? null : xFile.path,
      xFile: xFile,
    );
  }
  
  /// Создает из bytes
  static CrossPlatformFile fromBytes(Uint8List bytes, String name) {
    return CrossPlatformFile._(
      name: name,
      bytes: bytes,
    );
  }
  
  /// Читает bytes файла
  Future<Uint8List> readAsBytes() async {
    if (_bytes != null) {
      return _bytes!;
    }
    if (_xFile != null) {
      return await _xFile!.readAsBytes();
    }
    throw Exception('Невозможно прочитать файл: нет данных');
  }
  
  /// Возвращает размер файла
  Future<int> get length async {
    final bytes = await readAsBytes();
    return bytes.length;
  }
  
  /// Проверяет, существует ли файл (на Web всегда true если есть данные)
  bool get exists {
    return _bytes != null || _xFile != null;
  }
  
  /// Возвращает расширение файла
  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }
  
  /// Возвращает MIME тип на основе расширения
  String get mimeType {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
}

/// Хелпер для конвертации списка XFile в CrossPlatformFile
List<CrossPlatformFile> xFilesToCrossPlatform(List<XFile> files) {
  return files.map((f) => CrossPlatformFile.fromXFile(f)).toList();
}

