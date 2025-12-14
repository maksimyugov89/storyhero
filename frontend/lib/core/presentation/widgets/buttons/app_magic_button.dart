import 'package:flutter/material.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/app_radius.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_shadows.dart';
import 'dart:ui' as ui;

/// Магическая кнопка с glow эффектом
class AppMagicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool isLoading;
  final Color? glowColor;
  final bool fullWidth;

  const AppMagicButton({
    super.key,
    required this.child,
    this.onPressed,
    this.gradient,
    this.width,
    this.height = 56,
    this.borderRadius = 16,
    this.padding,
    this.isLoading = false,
    this.glowColor,
    this.fullWidth = false,
  });

  @override
  State<AppMagicButton> createState() => _AppMagicButtonState();
}

class _AppMagicButtonState extends State<AppMagicButton>
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

    Widget button = AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width ?? (widget.fullWidth ? double.infinity : null),
          height: widget.height,
          decoration: BoxDecoration(
            gradient: widget.gradient ?? AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: AppShadows.glowPrimary(
              opacity: _glowAnimation.value * 0.5,
              blur: 20 * _glowAnimation.value,
              spread: 2 * _glowAnimation.value,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.isLoading ? null : widget.onPressed,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Container(
                padding: widget.padding ??
                    AppSpacing.paddingHMD + AppSpacing.paddingVMD,
                alignment: Alignment.center,
                child: widget.isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.onPrimary,
                          ),
                        ),
                      )
                    : widget.child,
              ),
            ),
          ),
        );
      },
    );

    if (widget.fullWidth && widget.width == null) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}

