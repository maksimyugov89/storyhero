import 'package:flutter/material.dart';
import '../../core/theme/app_theme_magic.dart';
import 'asset_icon.dart';
import '../../core/utils/text_style_helpers.dart';

/// Градиентная кнопка Disney-стиля с анимированным свечением
class GlowingCapsuleButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final String? iconAsset;
  final VoidCallback? onPressed;
  final double? width;
  final double height;
  final double borderRadius;
  final bool isLoading;
  final Gradient? gradient;
  final TextStyle? textStyle;
  final Color? iconColor;

  const GlowingCapsuleButton({
    super.key,
    required this.text,
    this.icon,
    this.iconAsset,
    this.onPressed,
    this.width,
    this.height = 56,
    this.borderRadius = 36,
    this.isLoading = false,
    this.gradient,
    this.textStyle,
    this.iconColor,
  });

  @override
  State<GlowingCapsuleButton> createState() => _GlowingCapsuleButtonState();
}

class _GlowingCapsuleButtonState extends State<GlowingCapsuleButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    
    // Анимация scale при нажатии
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    // Анимация свечения
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultGradient = widget.gradient ?? AppThemeMagic.primaryGradient;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: widget.onPressed != null ? _onTapDown : null,
        onTapUp: widget.onPressed != null ? _onTapUp : null,
        onTapCancel: widget.onPressed != null ? _onTapCancel : null,
        child: AnimatedBuilder(
          animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
          builder: (context, child) {
            final scaleValue = _scaleAnimation.value;
            final glowValue = _glowAnimation.value * (_isHovered ? 1.2 : 1.0);

            // Градиент для свечения
            final glowGradient = LinearGradient(
              colors: [
                primaryColor.withOpacity(0.3 * glowValue),
                secondaryColor.withOpacity(0.3 * glowValue),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            );

            return Transform.scale(
              scale: scaleValue,
              child: Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  gradient: defaultGradient,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.4 * glowValue),
                      blurRadius: 20 * glowValue,
                      spreadRadius: 2 * glowValue,
                    ),
                    BoxShadow(
                      color: secondaryColor.withOpacity(0.3 * glowValue),
                      blurRadius: 15 * glowValue,
                      spreadRadius: 1 * glowValue,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.isLoading ? null : widget.onPressed,
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    splashColor: Colors.white.withOpacity(0.3),
                    highlightColor: Colors.white.withOpacity(0.1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      alignment: Alignment.center,
                      child: widget.isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (widget.icon != null || widget.iconAsset != null) ...[
                                  widget.iconAsset != null
                                      ? AssetIcon(
                                          assetPath: widget.iconAsset!,
                                          size: 20,
                                          color: widget.iconColor ?? Colors.white,
                                        )
                                      : Icon(
                                          widget.icon,
                                          color: widget.iconColor ?? Colors.white,
                                          size: 20,
                                        ),
                                  const SizedBox(width: 12),
                                ],
                                Flexible(
                                  child: Text(
                                    widget.text,
                                    style: widget.textStyle ??
                                        safeTextStyle(
                                          color: Colors.white,
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

