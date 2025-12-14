import 'package:flutter/material.dart';

class MagicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? boxShadow;
  final bool isLoading;

  const MagicButton({
    super.key,
    required this.child,
    this.onPressed,
    this.gradient,
    this.width,
    this.height = 56,
    this.borderRadius = 30,
    this.padding,
    this.boxShadow,
    this.isLoading = false,
  });

  @override
  State<MagicButton> createState() => _MagicButtonState();
}

class _MagicButtonState extends State<MagicButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

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
    _glowController.stop();
    _scaleController.stop();
    _glowController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final defaultGradient = LinearGradient(
      colors: [
        Theme.of(context).colorScheme.primary,
        Theme.of(context).colorScheme.secondary,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final defaultShadow = [
      BoxShadow(
        color: (widget.gradient?.colors.first ?? 
                Theme.of(context).colorScheme.primary).withOpacity(0.4),
        blurRadius: 20,
        spreadRadius: 0,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: (widget.gradient?.colors.first ?? 
                Theme.of(context).colorScheme.primary).withOpacity(0.2),
        blurRadius: 40,
        spreadRadius: -5,
        offset: const Offset(0, 16),
      ),
    ];

    return GestureDetector(
      onTapDown: widget.onPressed != null && !widget.isLoading ? _onTapDown : null,
      onTapUp: widget.onPressed != null && !widget.isLoading ? _onTapUp : null,
      onTapCancel: widget.onPressed != null && !widget.isLoading ? _onTapCancel : null,
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
        builder: (context, child) {
          final glowValue = _glowAnimation.value;
          final scaleValue = _scaleAnimation.value;
          final effectiveShadow = widget.boxShadow ?? 
            defaultShadow.map((s) => BoxShadow(
              color: s.color.withOpacity(s.color.opacity * glowValue),
              blurRadius: s.blurRadius * glowValue,
              spreadRadius: s.spreadRadius,
              offset: s.offset,
            )).toList();

          return Transform.scale(
            scale: scaleValue,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                gradient: widget.gradient ?? defaultGradient,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: effectiveShadow,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onPressed,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  child: Container(
                    padding: widget.padding ??
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    alignment: Alignment.center,
                    child: widget.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : child ?? widget.child,
                  ),
                ),
              ),
            ),
          );
        },
        child: widget.child, // Кешируем child
      ),
    );
  }
}

