import 'package:flutter/foundation.dart';

class ImageUrl {
  static const String _prodBaseUrl = 'https://storyhero.ru';

  /// Приводит относительные пути (/static/...) к абсолютным URL для Web
  /// Правила:
  /// - Если url == null или пустая строка → вернуть "".
  /// - Если url начинается с "http://" или "https://" → вернуть url как есть.
  /// - Если url начинается с "//" → добавить "https:" в начало.
  /// - Если url начинается с "/static/" → превратить в "${BASE_URL}${url}".
  /// - Если url начинается с "static/" → превратить в "${BASE_URL}/${url}".
  /// - Иначе вернуть url как есть (не ломаем data: или blob:).
  static String resolve(String? path) {
    if (path == null || path.isEmpty) {
      if (kDebugMode) {
        print('[ImageUrl] resolve: null/empty -> ""');
      }
      return '';
    }

    // Уже абсолютный URL
    if (path.startsWith('http://') || path.startsWith('https://')) {
      if (kDebugMode) {
        print('[ImageUrl] resolve: absolute URL -> "$path"');
      }
      return path;
    }

    // Протокол-относительный URL (//example.com/image.jpg)
    if (path.startsWith('//')) {
      final resolved = 'https:$path';
      if (kDebugMode) {
        print('[ImageUrl] resolve: protocol-relative "$path" -> "$resolved"');
      }
      return resolved;
    }

    // Относительные пути, которые нужно преобразовать в абсолютные для Web
    // (и для мобильных тоже, чтобы обеспечить консистентность)
    if (path.startsWith('/static/') || path.startsWith('static/')) {
      final resolved = path.startsWith('/static/')
          ? '$_prodBaseUrl$path'
          : '$_prodBaseUrl/$path';

      if (kDebugMode) {
        print('[ImageUrl] resolve: static path "$path" -> "$resolved"');
      }
      return resolved;
    }

    // Для Web любые другие относительные пути могут ломаться, но мы не знаем,
    // как их резолвить. Оставляем как есть, но логируем предупреждение.
    if (kIsWeb && (path.startsWith('/') || path.contains('://') == false)) {
      if (kDebugMode) {
        print('[ImageUrl] WARNING: relative path on Web may not work: "$path"');
      }
    }

    if (kDebugMode) {
      print('[ImageUrl] resolve: unchanged -> "$path"');
    }
    return path;
  }
}
