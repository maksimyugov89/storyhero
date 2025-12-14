import 'dart:math' as math;
import 'package:flutter/material.dart';

class FlyingParticles extends StatefulWidget {
  final int particleCount;
  final Color? particleColor;
  final double particleSize;
  final bool isStars;

  const FlyingParticles({
    super.key,
    this.particleCount = 30,
    this.particleColor,
    this.particleSize = 4,
    this.isStars = false,
  });

  @override
  State<FlyingParticles> createState() => _FlyingParticlesState();
}

class _FlyingParticlesState extends State<FlyingParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Particle> _particles;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _particles = List.generate(
      widget.particleCount,
      (index) => Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        speed: 0.3 + _random.nextDouble() * 0.5,
        size: widget.particleSize + _random.nextDouble() * widget.particleSize,
        delay: _random.nextDouble(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.particleColor ??
        (isDark
            ? Colors.white.withOpacity(0.6)
            : Theme.of(context).colorScheme.primary.withOpacity(0.4));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned.fill(
          child: CustomPaint(
            painter: _ParticlePainter(
              particles: _particles,
              progress: _controller.value,
              color: color,
              isStars: widget.isStars,
            ),
          ),
        );
      },
    );
  }
}

class Particle {
  final double x;
  final double y;
  final double speed;
  final double size;
  final double delay;

  Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.delay,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;
  final Color color;
  final bool isStars;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.color,
    required this.isStars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final particle in particles) {
      final normalizedProgress = (progress + particle.delay) % 1.0;
      final y = (particle.y + normalizedProgress * particle.speed) % 1.0;

      if (isStars) {
        _drawStar(
          canvas,
          Offset(particle.x * size.width, y * size.height),
          particle.size,
          paint,
        );
      } else {
        canvas.drawCircle(
          Offset(particle.x * size.width, y * size.height),
          particle.size,
          paint..color = color.withOpacity(0.6 - normalizedProgress * 0.4),
        );
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final outerRadius = size;
    final innerRadius = size * 0.5;
    final spikes = 5;

    for (int i = 0; i < spikes * 2; i++) {
      final radius = i % 2 == 0 ? outerRadius : innerRadius;
      final angle = (i * math.pi) / spikes;
      final x = center.dx + radius * math.cos(angle - math.pi / 2);
      final y = center.dy + radius * math.sin(angle - math.pi / 2);
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

