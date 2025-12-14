import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/app_radius.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_shadows.dart';

/// Магическая карточка с glow эффектом
class AppMagicCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? glowColor;
  final bool selected;
  final Gradient? gradient;

  const AppMagicCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.glowColor,
    this.selected = false,
    this.gradient,
  });

  @override
  State<AppMagicCard> createState() => _AppMagicCardState();
}

class _AppMagicCardState extends State<AppMagicCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.glowColor ?? AppColors.primary;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: widget.margin ?? AppSpacing.paddingSM,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            color: widget.gradient == null ? AppColors.surface : null,
            borderRadius: AppRadius.radiusLG,
            border: widget.selected
                ? Border.all(
                    color: glowColor,
                    width: 2,
                  )
                : null,
            boxShadow: widget.selected || widget.onTap != null
                ? AppShadows.glowPrimary(
                    opacity: _glowAnimation.value * 0.5,
                    blur: 20 * _glowAnimation.value,
                    spread: 2 * _glowAnimation.value,
                  )
                : AppShadows.soft,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: AppRadius.radiusLG,
              child: Padding(
                padding: widget.padding ?? AppSpacing.paddingMD,
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}









