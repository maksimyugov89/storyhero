import 'package:flutter/material.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/app_shadows.dart';
import '../../../../ui/components/asset_icon.dart';

/// Магический loader с вращающимся порталом
class AppMagicLoader extends StatefulWidget {
  final double size;
  final Color? glowColor;

  const AppMagicLoader({
    super.key,
    this.size = 48,
    this.glowColor,
  });

  @override
  State<AppMagicLoader> createState() => _AppMagicLoaderState();
}

class _AppMagicLoaderState extends State<AppMagicLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.glowColor ?? AppColors.primary;

    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationController.value * 2 * 3.14159,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: AppShadows.glowPrimary(
                opacity: 0.6,
                blur: 20,
                spread: 2,
              ),
            ),
            child: AssetIcon(
              assetPath: AppIcons.magicPortal,
              size: widget.size,
              color: glowColor,
            ),
          ),
        );
      },
    );
  }
}

