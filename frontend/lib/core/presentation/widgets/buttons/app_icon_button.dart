import 'package:flutter/material.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/app_radius.dart';
import '../../../../ui/components/asset_icon.dart';

/// Кнопка-круг с иконкой
class AppIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? iconAsset;
  final IconData? icon;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;
  final String? tooltip;

  const AppIconButton({
    super.key,
    this.onPressed,
    this.iconAsset,
    this.icon,
    this.size = 48,
    this.backgroundColor,
    this.iconColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: backgroundColor ?? AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          child: iconAsset != null
              ? AssetIcon(
                  assetPath: iconAsset!,
                  size: size * 0.5,
                  color: iconColor ?? AppColors.onSurface,
                )
              : Icon(
                  icon,
                  size: size * 0.5,
                  color: iconColor ?? AppColors.onSurface,
                ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}

