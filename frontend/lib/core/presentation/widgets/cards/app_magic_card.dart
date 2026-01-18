import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

    final baseColor = widget.gradient == null
        ? (kIsWeb ? AppColors.surfaceVariant.withOpacity(0.9) : AppColors.surface)
        : null;

    final baseCard = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: widget.margin ?? AppSpacing.paddingSM,
      decoration: BoxDecoration(
        gradient: widget.gradient,
        color: baseColor,
        borderRadius: AppRadius.radiusLG,
        border: widget.selected
            ? Border.all(
                color: glowColor,
                width: 2,
              )
            : null,
        boxShadow: widget.selected || widget.onTap != null
            ? AppShadows.glowPrimary(
                opacity: glowValue * 0.35,
                blur: 16 * glowValue,
                spread: 1.5 * glowValue,
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
    Widget card = baseCard;

    if (!_animateGlow || _glowAnimation == null) {
      if (kIsWeb && widget.onTap != null) {
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 140),
            scale: _isHovered ? 1.01 : 1.0,
            child: card,
          ),
        );
      }
      return card;
    }

    Widget animated = AnimatedBuilder(
      animation: _glowAnimation!,
      child: baseCard,
      builder: (context, child) => child!,
    );

    if (kIsWeb && widget.onTap != null) {
      animated = MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          scale: _isHovered ? 1.01 : 1.0,
          child: animated,
        ),
      );
    }

    return animated;
  }
}









