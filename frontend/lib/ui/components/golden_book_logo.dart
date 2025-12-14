import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Золотая открытая книга с буквами SH и вылетающими звездами
class GoldenBookLogo extends StatefulWidget {
  final double size;

  const GoldenBookLogo({
    super.key,
    this.size = 200,
  });

  @override
  State<GoldenBookLogo> createState() => _GoldenBookLogoState();
}

class _GoldenBookLogoState extends State<GoldenBookLogo>
    with TickerProviderStateMixin {
  late AnimationController _starController;
  late AnimationController _glowController;
  late List<_Star> _stars;

  @override
  void initState() {
    super.initState();

    _starController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    // Создаем звезды
    _stars = List.generate(8, (index) {
      return _Star(
        angle: (index / 8) * 2 * math.pi,
        distance: 60 + (index % 3) * 20,
        speed: 0.5 + (index % 3) * 0.2,
        size: 4 + (index % 2) * 2,
      );
    });
  }

  @override
  void dispose() {
    _starController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_starController, _glowController]),
      builder: (context, child) {
        final glowValue = (_glowController.value * 0.3) + 0.7;
        
        return CustomPaint(
          size: Size(widget.size, widget.size * 0.8),
          painter: _GoldenBookPainter(
            stars: _stars,
            progress: _starController.value,
            glowValue: glowValue,
          ),
        );
      },
    );
  }
}

class _Star {
  final double angle;
  final double distance;
  final double speed;
  final double size;

  _Star({
    required this.angle,
    required this.distance,
    required this.speed,
    required this.size,
  });
}

class _GoldenBookPainter extends CustomPainter {
  final List<_Star> stars;
  final double progress;
  final double glowValue;

  _GoldenBookPainter({
    required this.stars,
    required this.progress,
    required this.glowValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Рисуем свечение вокруг книги
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD93D).withOpacity(0.3 * glowValue),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: size.width * 0.6),
      );
    canvas.drawCircle(center, size.width * 0.6, glowPaint);

    // Рисуем книгу
    _drawBook(canvas, center, size);

    // Рисуем вылетающие звезды
    _drawStars(canvas, center);
  }

  void _drawBook(Canvas canvas, Offset center, Size size) {
    final bookWidth = size.width * 0.6;
    final bookHeight = size.height * 0.7;
    final spineWidth = bookWidth * 0.1;

    // Золотая обложка (левая сторона)
    final leftCoverPaint = Paint()
      ..color = const Color(0xFFFFD93D)
      ..style = PaintingStyle.fill;
    
    final leftCoverPath = Path()
      ..addRect(Rect.fromLTWH(
        center.dx - bookWidth / 2,
        center.dy - bookHeight / 2,
        bookWidth / 2,
        bookHeight,
      ));
    canvas.drawPath(leftCoverPath, leftCoverPaint);

    // Розовые страницы
    final pagesPaint = Paint()
      ..color = const Color(0xFFF277E6)
      ..style = PaintingStyle.fill;
    
    final pagesPath = Path()
      ..addRect(Rect.fromLTWH(
        center.dx - spineWidth / 2,
        center.dy - bookHeight / 2,
        bookWidth + spineWidth,
        bookHeight,
      ));
    canvas.drawPath(pagesPath, pagesPaint);

    // Золотая обложка (правая сторона)
    final rightCoverPaint = Paint()
      ..color = const Color(0xFFFFD93D)
      ..style = PaintingStyle.fill;
    
    final rightCoverPath = Path()
      ..addRect(Rect.fromLTWH(
        center.dx,
        center.dy - bookHeight / 2,
        bookWidth / 2,
        bookHeight,
      ));
    canvas.drawPath(rightCoverPath, rightCoverPaint);

    // Золотой корешок
    final spinePaint = Paint()
      ..color = const Color(0xFFFFB93D)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - spineWidth / 2,
        center.dy - bookHeight / 2,
        spineWidth,
        bookHeight,
      ),
      spinePaint,
    );

    // Буквы SH
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Буква S на левой странице
    textPainter.text = TextSpan(
      text: 'S',
      style: TextStyle(
        fontSize: bookHeight * 0.4,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFFFD93D),
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - bookWidth / 4 - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    // Буква H на правой странице
    textPainter.text = TextSpan(
      text: 'H',
      style: TextStyle(
        fontSize: bookHeight * 0.4,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFFFD93D),
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx + bookWidth / 4 - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawStars(Canvas canvas, Offset center) {
    final starPaint = Paint()
      ..color = const Color(0xFFFFD93D)
      ..style = PaintingStyle.fill;

    for (final star in stars) {
      final currentAngle = star.angle + progress * star.speed * 2 * math.pi;
      final x = center.dx + star.distance * math.cos(currentAngle);
      final y = center.dy + star.distance * math.sin(currentAngle);

      _drawStar(canvas, Offset(x, y), star.size, starPaint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final outerRadius = size;
    final innerRadius = size * 0.5;
    final spikes = 5;

    for (int i = 0; i < spikes * 2; i++) {
      final radius = i % 2 == 0 ? outerRadius : innerRadius;
      final angle = (i * math.pi) / spikes - math.pi / 2;
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


