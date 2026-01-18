import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class GlassmorphicCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final double blur;
  final Color? borderColor;
  final double? width;
  final double? height;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 24,
    this.onTap,
    this.blur = 5, // Уменьшен для производительности (soft blur)
    this.borderColor,
    this.width,
    this.height,
  });

  @override
  State<GlassmorphicCard> createState() => _GlassmorphicCardState();
}

class _GlassmorphicCardState extends State<GlassmorphicCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _floatController;
  Animation<double>? _floatAnimation;
  late final bool _enableFloat;

  @override
  void initState() {
    super.initState();
    _enableFloat = !kIsWeb && widget.onTap != null;
    if (_enableFloat) {
      _floatController = AnimationController(
        duration: const Duration(seconds: 4),
        vsync: this,
      )..repeat(reverse: true);
      _floatAnimation = Tween<double>(begin: -2, end: 2).animate(
        CurvedAnimation(parent: _floatController!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    _floatController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBorderColor = isDark
        ? Colors.white.withOpacity(0.25)
        : Colors.white.withOpacity(0.6);
    Widget content = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: widget.borderColor ?? defaultBorderColor,
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: widget.blur,
            sigmaY: widget.blur,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withOpacity(0.14),
                        Colors.white.withOpacity(0.08),
                      ]
                    : [
                        Colors.white.withOpacity(0.7),
                        Colors.white.withOpacity(0.5),
                      ],
              ),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: Container(
                  padding: widget.padding ?? const EdgeInsets.all(20),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!_enableFloat || _floatAnimation == null) {
      return content;
    }

    return AnimatedBuilder(
      animation: _floatAnimation!,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation!.value),
          child: content,
        );
      },
    );
  }
}

