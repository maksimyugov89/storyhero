import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/utils/text_style_helpers.dart';

/// Магический фон с рунами и вихрями из блесток
class MagicRunicBackground extends StatefulWidget {
  final Widget? child;
  final bool isDark;

  const MagicRunicBackground({
    super.key,
    this.child,
    this.isDark = true,
  });

  @override
  State<MagicRunicBackground> createState() => _MagicRunicBackgroundState();
}

class _MagicRunicBackgroundState extends State<MagicRunicBackground>
    with TickerProviderStateMixin {
  late AnimationController _swirlController;
  late AnimationController _particleController;
  late AnimationController _runeController;

  @override
  void initState() {
    super.initState();

    _swirlController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();

    _particleController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _runeController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _swirlController.dispose();
    _particleController.dispose();
    _runeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark ||
        Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF1C1033), // Темно-фиолетовый
                  const Color(0xFF431A5A), // Фиолетовый
                  const Color(0xFF2A1F5C), // Темный пурпурный
                ]
              : [
                  const Color(0xFFF5F7FF),
                  const Color(0xFFE8ECF1),
                  const Color(0xFFDDE4EB),
                ],
        ),
      ),
      child: Stack(
        children: [
          // Верхняя светящаяся полоса с рунами
          AnimatedBuilder(
            animation: _swirlController,
            builder: (context, child) {
              return CustomPaint(
                painter: _RunicArcPainter(
                  progress: _swirlController.value,
                  isDark: isDark,
                ),
                size: Size.infinite,
              );
            },
          ),
          // Вихри из блесток
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                painter: _SparkleSwirlPainter(
                  progress: _particleController.value,
                  isDark: isDark,
                ),
                size: Size.infinite,
              );
            },
          ),
          // Основной контент
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

/// Художник для верхней дуги с рунами
class _RunicArcPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _RunicArcPainter({
    required this.progress,
    required this.isDark,
  });

  // Простые рунические символы (стилизованные)
  final List<String> _runes = ['⚡', '✦', '◉', '◈', '◆', '◊'];

  @override
  void paint(Canvas canvas, Size size) {
    if (!size.width.isFinite || !size.height.isFinite || size.width <= 0 || size.height <= 0) {
      return;
    }
    
    // Рисуем светящуюся дугу
    final arcPath = Path();
    final centerY = size.height * 0.25;
    final radius = size.width * 0.8;
    
    arcPath.addArc(
      Rect.fromCenter(
        center: Offset(size.width / 2, centerY),
        width: radius,
        height: radius * 0.5,
      ),
      0.3,
      2.5,
    );

    // Градиент для дуги
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 60
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF9B5EFF).withOpacity(0.4), // Фиолетовый
          const Color(0xFFF277E6).withOpacity(0.3), // Розовый
          const Color(0xFFFFD93D).withOpacity(0.5), // Золотой
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawPath(arcPath, paint);

    // Рисуем руны вдоль дуги
    final runePaint = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < 8; i++) {
      final t = i / 7.0;
      final angle = 0.3 + t * 2.5;
      final x = size.width / 2 + radius / 2 * math.cos(angle);
      final y = centerY + radius / 4 * math.sin(angle);

      runePaint.text = TextSpan(
        text: _runes[i % _runes.length],
        style: safeTextStyle(
          fontSize: 20,
          color: const Color(0xFFFFD93D).withOpacity(0.6),
        ).copyWith(
          shadows: [
            Shadow(
              color: const Color(0xFFFFD93D).withOpacity(0.8),
              blurRadius: 8,
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

/// Художник для вихрей из блесток
class _SparkleSwirlPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _SparkleSwirlPainter({
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Создаем вихри из золотых блесток
    for (int i = 0; i < 30; i++) {
      final angle = (progress * 2 * math.pi) + (i * 0.2);
      final radius = 100 + (i % 3) * 50;
      final x = size.width / 2 + radius * math.cos(angle);
      final y = size.height / 2 + radius * math.sin(angle);

      // Размер блестки зависит от позиции
      final sparkleSize = 2 + (i % 3) * 1.5;
      final opacity = 0.3 + (math.sin(progress * 2 * math.pi + i) + 1) / 4;

      paint.color = const Color(0xFFFFD93D).withOpacity(opacity);
      
      // Рисуем блестку в виде звезды
      _drawSparkle(canvas, Offset(x, y), sparkleSize, paint);
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final spikes = 4;
    
    for (int i = 0; i < spikes * 2; i++) {
      final radius = i % 2 == 0 ? size : size * 0.5;
      final angle = (i * math.pi) / spikes;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


