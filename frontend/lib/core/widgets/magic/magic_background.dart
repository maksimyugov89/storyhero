import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Магический фон с 3D-parallax эффектом
class MagicBackground extends StatefulWidget {
  final Widget? child;
  final bool isDark;

  const MagicBackground({
    super.key,
    this.child,
    this.isDark = true,
  });

  @override
  State<MagicBackground> createState() => _MagicBackgroundState();
}

class _MagicBackgroundState extends State<MagicBackground>
    with TickerProviderStateMixin {
  Offset _offset = Offset.zero;
  late AnimationController _resetController;
  // ignore: unused_field
  late Animation<Offset> _resetAnimation;

  // Анимационные контроллеры для плавающих частиц
  late AnimationController _particleController1;
  late AnimationController _particleController2;
  late AnimationController _particleController3;

  @override
  void initState() {
    super.initState();

    _resetController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _resetAnimation = Tween<Offset>(
      begin: _offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeOut,
    ));

    _particleController1 = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);

    _particleController2 = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat(reverse: true);

    _particleController3 = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _resetController.dispose();
    _particleController1.dispose();
    _particleController2.dispose();
    _particleController3.dispose();
    super.dispose();
  }

  void _updateOffset(Offset delta) {
    setState(() {
      _offset += delta / 40; // коэффициент для плавности
      _offset = Offset(
        _offset.dx.clamp(-10.0, 10.0),
        _offset.dy.clamp(-10.0, 10.0),
      );
    });
  }

  void _resetOffset() {
    _resetController.forward(from: 0.0).then((_) {
      setState(() {
        _offset = Offset.zero;
      });
      _resetController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark ||
        Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onPanUpdate: (details) => _updateOffset(details.delta),
      onPanEnd: (_) => _resetOffset(),
      child: MouseRegion(
        onHover: (event) {
          final screenSize = MediaQuery.of(context).size;
          final centerX = screenSize.width / 2;
          final centerY = screenSize.height / 2;
          final deltaX = (event.localPosition.dx - centerX) / centerX;
          final deltaY = (event.localPosition.dy - centerY) / centerY;
          _updateOffset(Offset(deltaX * 2, deltaY * 2));
        },
        onExit: (_) => _resetOffset(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      const Color(0xFF1C1033),
                      const Color(0xFF431A5A),
                      const Color(0xFF2A1F5C),
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
              // Параллакс-слои с разной глубиной
              _ParallaxLayer(
                offset: _offset,
                depth: 6,
                child: _BlurCircle(
                  size: 400,
                  color: isDark
                      ? const Color(0xFF9B5EFF).withOpacity(0.15)
                      : const Color(0xFF9B5EFF).withOpacity(0.08),
                  position: Offset(0.2, 0.3),
                  animation: _particleController1,
                ),
              ),
              _ParallaxLayer(
                offset: _offset,
                depth: 4,
                child: _BlurCircle(
                  size: 350,
                  color: isDark
                      ? const Color(0xFFF277E6).withOpacity(0.12)
                      : const Color(0xFFF277E6).withOpacity(0.06),
                  position: Offset(0.8, 0.6),
                  animation: _particleController2,
                ),
              ),
              _ParallaxLayer(
                offset: _offset,
                depth: 2,
                child: _BlurCircle(
                  size: 300,
                  color: isDark
                      ? const Color(0xFF6BCAE2).withOpacity(0.1)
                      : const Color(0xFF6BCAE2).withOpacity(0.05),
                  position: Offset(0.5, 0.7),
                  animation: _particleController3,
                ),
              ),
              // Звёзды/частицы
              ...List.generate(
                15,
                (index) => _ParallaxLayer(
                  offset: _offset,
                  depth: 8 + (index % 3),
                  child: _StarParticle(
                    position: Offset(
                      (index * 0.1) % 1.0,
                      (index * 0.15) % 1.0,
                    ),
                    size: 2 + (index % 3),
                    animation: _particleController1,
                    delay: index * 0.1,
                  ),
                ),
              ),
              // Основной контент
              if (widget.child != null) widget.child!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Слой с параллакс-эффектом
class _ParallaxLayer extends StatelessWidget {
  final Offset offset;
  final double depth;
  final Widget child;

  const _ParallaxLayer({
    required this.offset,
    required this.depth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(-offset.dx / depth, -offset.dy / depth),
      child: child,
    );
  }
}

/// Размытый круг для фона
class _BlurCircle extends StatelessWidget {
  final double size;
  final Color color;
  final Offset position;
  final Animation<double> animation;

  const _BlurCircle({
    required this.size,
    required this.color,
    required this.position,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final moveX = math.sin(animation.value * 2 * math.pi) * 0.05;
        final moveY = math.cos(animation.value * 2 * math.pi) * 0.03;
        return Positioned(
          left: screenSize.width * (position.dx + moveX) - size / 2,
          top: screenSize.height * (position.dy + moveY) - size / 2,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color,
                  color.withOpacity(0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Звёздная частица
class _StarParticle extends StatelessWidget {
  final Offset position;
  final double size;
  final Animation<double> animation;
  final double delay;

  const _StarParticle({
    required this.position,
    required this.size,
    required this.animation,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final opacity = (math.sin((animation.value + delay) * 2 * math.pi) + 1) /
            2;
        return Positioned(
          left: screenSize.width * position.dx,
          top: screenSize.height * position.dy,
          child: Opacity(
            opacity: opacity * 0.8,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withOpacity(0.6)
                    : Colors.blue.withOpacity(0.4),
              ),
            ),
          ),
        );
      },
    );
  }
}

