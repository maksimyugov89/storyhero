import 'package:flutter/material.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/app_radius.dart';
import '../../design_system/app_shadows.dart';
import '../../../../ui/components/asset_icon.dart';

/// Floating Action Button с bounce и glow эффектом
class AppFAB extends StatefulWidget {
  final VoidCallback? onPressed;
  final String? iconAsset;
  final IconData? icon;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? glowColor;

  const AppFAB({
    super.key,
    this.onPressed,
    this.iconAsset,
    this.icon,
    this.tooltip,
    this.backgroundColor,
    this.glowColor,
  });

  @override
  State<AppFAB> createState() => _AppFABState();
}

class _AppFABState extends State<AppFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.glowColor ?? AppColors.primary;

    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _bounceAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: AppShadows.glowPrimary(
                opacity: 0.5,
                blur: 20,
                spread: 2,
              ),
            ),
            child: FloatingActionButton(
              onPressed: widget.onPressed,
              backgroundColor: widget.backgroundColor ?? AppColors.primary,
              tooltip: widget.tooltip,
              child: widget.iconAsset != null
                  ? AssetIcon(
                      assetPath: widget.iconAsset!,
                      size: 24,
                      color: AppColors.onPrimary,
                    )
                  : Icon(
                      widget.icon ?? Icons.add,
                      color: AppColors.onPrimary,
                    ),
            ),
          ),
        );
      },
    );
  }
}

