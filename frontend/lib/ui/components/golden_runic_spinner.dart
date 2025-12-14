import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Золотой спиральный индикатор загрузки из рун
class GoldenRunicSpinner extends StatefulWidget {
  final double size;
  final String? message;

  const GoldenRunicSpinner({
    super.key,
    this.size = 100,
    this.message,
  });

  @override
  State<GoldenRunicSpinner> createState() => _GoldenRunicSpinnerState();
}

class _GoldenRunicSpinnerState extends State<GoldenRunicSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Рунные символы
  final List<String> _runes = ['⚡', '✦', '◉', '◈', '◆', '◊', '◊', '◊'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _RunicSpiralPainter(
                progress: _controller.value,
                runes: _runes,
              ),
            );
          },
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.message!,
            style: (Theme.of(context).textTheme.bodyMedium ?? 
                    const TextStyle(fontSize: 14)).copyWith(
                  color: const Color(0xFFFFD93D).withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _RunicSpiralPainter extends CustomPainter {
  final double progress;
  final List<String> runes;

  _RunicSpiralPainter({
    required this.progress,
    required this.runes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.4;
    
    // Рисуем спираль из рун
    final spiralPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFFD93D).withOpacity(0.8),
          const Color(0xFFFFD93D).withOpacity(0.3),
        ],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    // Спираль
    final spiralPath = Path();
    for (int i = 0; i < runes.length; i++) {
      final t = (i / runes.length) + (progress % 1);
      final angle = t * 4 * math.pi; // Два полных оборота
      final radius = maxRadius * (t % 1);
      
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      if (i == 0) {
        spiralPath.moveTo(x, y);
      } else {
        spiralPath.lineTo(x, y);
      }
    }
    canvas.drawPath(spiralPath, spiralPaint);

    // Рисуем руны вдоль спирали
    final runePaint = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < runes.length; i++) {
      final t = (i / runes.length) + (progress % 1);
      final angle = t * 4 * math.pi;
      final radius = maxRadius * (t % 1);
      
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      runePaint.text = TextSpan(
        text: runes[i],
        style: TextStyle(
          fontSize: 16,
          color: const Color(0xFFFFD93D).withOpacity(0.9 - (t % 1) * 0.5),
          shadows: [
            Shadow(
              color: const Color(0xFFFFD93D).withOpacity(0.8),
              blurRadius: 6,
            ),
          ],
        ),
      );
      runePaint.layout();
      runePaint.paint(
        canvas,
        Offset(x - runePaint.width / 2, y - runePaint.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


