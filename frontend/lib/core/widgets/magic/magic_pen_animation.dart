import 'dart:math' as math;
import 'package:flutter/material.dart';

class MagicPenAnimation extends StatefulWidget {
  final double size;
  final bool isActive;

  const MagicPenAnimation({
    super.key,
    this.size = 100,
    this.isActive = true,
  });

  @override
  State<MagicPenAnimation> createState() => _MagicPenAnimationState();
}

class _MagicPenAnimationState extends State<MagicPenAnimation>
    with TickerProviderStateMixin {
  late AnimationController _penController;
  late AnimationController _sparkleController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _sparkleAnimation;

  @override
  void initState() {
    super.initState();

    _penController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(begin: -0.2, end: 0.2).animate(
      CurvedAnimation(parent: _penController, curve: Curves.easeInOut),
    );

    _sparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sparkleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _penController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Летающие искры
          ...List.generate(8, (index) {
            final angle = (index * math.pi * 2) / 8;
            final distance = widget.size * 0.4;
            return AnimatedBuilder(
              animation: _sparkleAnimation,
              builder: (context, child) {
                final progress = (_sparkleAnimation.value + index * 0.125) % 1.0;
                final currentDistance = distance * progress;
                return Transform.translate(
                  offset: Offset(
                    math.cos(angle) * currentDistance,
                    math.sin(angle) * currentDistance,
                  ),
                  child: Opacity(
                    opacity: 1.0 - progress,
                    child: Container(
                      width: 4 + progress * 2,
                      height: 4 + progress * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          // Перо
          AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value,
                child: CustomPaint(
                  size: Size(widget.size * 0.6, widget.size),
                  painter: _PenPainter(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PenPainter extends CustomPainter {
  final Color color;

  _PenPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    // Корпус пера
    path.moveTo(size.width * 0.3, 0);
    path.lineTo(size.width * 0.7, 0);
    path.lineTo(size.width * 0.9, size.height * 0.7);
    path.lineTo(size.width * 0.5, size.height);
    path.lineTo(size.width * 0.1, size.height * 0.7);
    path.close();

    canvas.drawPath(path, paint);

    // Детали пера
    final detailPaint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(size.width * 0.5, 0),
      Offset(size.width * 0.5, size.height * 0.7),
      detailPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

