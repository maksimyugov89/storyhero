import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_shadows.dart';

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
  AnimationController? _glowController;
  Animation<double>? _glowAnimation;
  late final bool _animateGlow;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animateGlow = !kIsWeb;
    if (_animateGlow) {
      _glowController = AnimationController(
        duration: const Duration(milliseconds: 2000),
        vsync: this,
      )..repeat(reverse: true);

      _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(
          parent: _glowController!,
          curve: Curves.easeInOut,
        ),
      );
    }
  }

  @override
  void dispose() {
    _glowController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.glowColor ?? AppColors.primary;
    final glowValue = _animateGlow ? (_glowAnimation?.value ?? 0.6) : 0.6;

    final baseButton = Container(
      width: widget.width ?? (widget.fullWidth ? double.infinity : null),
      height: widget.height,
      decoration: BoxDecoration(
        gradient: widget.gradient ?? AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: AppShadows.glowPrimary(
          opacity: glowValue * 0.35,
          blur: 16 * glowValue,
          spread: 1.5 * glowValue,
          glowColor: glowColor,
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

    Widget button = baseButton;
    if (_animateGlow && _glowAnimation != null) {
      button = AnimatedBuilder(
        animation: _glowAnimation!,
        child: baseButton,
        builder: (context, child) => child!,
      );
    }

    if (kIsWeb) {
      button = MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: _isHovered ? 1.02 : 1.0,
          child: button,
        ),
      );
    }

    if (widget.fullWidth && widget.width == null) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}

