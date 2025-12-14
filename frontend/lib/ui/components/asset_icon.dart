import 'package:flutter/material.dart';

/// Виджет для отображения PNG-иконок из локальных assets.
/// ВСЕГДА использует Image.asset, НИКОГДА не использует NetworkImage.
class AssetIcon extends StatelessWidget {
  const AssetIcon({
    super.key,
    required this.assetPath,
    this.size = 24,
    this.color,
  });

  final String assetPath;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Гарантируем, что путь начинается с 'assets/'
    final String normalizedPath = assetPath.startsWith('assets/')
        ? assetPath
        : 'assets/$assetPath';

    // ВСЕГДА используем Image.asset - НИКОГДА NetworkImage
    // ВАЖНО: PNG иконки цветные, поэтому НЕ передаем color в Image.asset
    // Параметр color в Image.asset применяет цветовой фильтр, который
    // делает цветные PNG белыми или невидимыми
    // ВАЖНО: НЕ используем cacheWidth/cacheHeight - это ломает систему плотности Flutter
    // Flutter автоматически выберет правильную плотность (1.0x/2.0x/3.0x) из папок
    return Image.asset(
      normalizedPath,
      width: size,
      height: size,
      // НЕ передаем color - иконки уже цветные PNG
      fit: BoxFit.contain,
      errorBuilder: (ctx, err, st) {
        // Логируем ошибку для отладки
        debugPrint('[AssetIcon] ❌ Ошибка загрузки: $normalizedPath');
        debugPrint('[AssetIcon] Ошибка: $err');
        // Возвращаем fallback иконку Material Icons
        return Icon(
          Icons.image_not_supported_outlined,
          size: size,
          color: color ?? Colors.grey[600],
        );
      },
    );
  }
}

class AppIcons {
  static const String addBook = 'assets/icon/icon_add_book.png';
  static const String alert = 'assets/icon/icon_alert.png';
  static const String back = 'assets/icon/icon_back.png';
  static const String childProfile = 'assets/icon/icon_child_profile.png';
  static const String delete = 'assets/icon/icon_delete.png';
  static const String draftPages = 'assets/icon/icon_draft_pages.png';
  static const String edit = 'assets/icon/icon_edit.png';
  static const String generateStory = 'assets/icon/icon_generate_story.png';
  static const String help = 'assets/icon/icon_help.png';
  static const String home = 'assets/icon/icon_home.png';
  static const String library = 'assets/icon/icon_library.png';
  static const String magicPortal = 'assets/icon/icon_magic_portal.png';
  static const String magicStar = 'assets/icon/icon_magic_star.png';
  static const String magicStyle = 'assets/icon/icon_magic_style.png';
  static const String myBooks = 'assets/icon/icon_my_books.png';
  static const String navigation = 'assets/icon/icon_navigation.png';
  static const String profile = 'assets/icon/icon_profile.png';
  static const String secureBook = 'assets/icon/icon_secure_book.png';
  static const String success = 'assets/icon/icon_success.png';
  
  // Aliases for compatibility
  static const String add = 'assets/icon/icon_add_book.png';
}
