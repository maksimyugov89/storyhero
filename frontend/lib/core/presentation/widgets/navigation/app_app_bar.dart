import 'package:flutter/material.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/app_typography.dart';

/// Кастомный AppBar с магическим стилем
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;

  const AppAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title != null
          ? Text(
              title!,
              style: AppTypography.headlineSmall,
            )
          : null,
      leading: leading,
      actions: actions,
      centerTitle: centerTitle,
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.onBackground,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}









