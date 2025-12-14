import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme_magic.dart';

/// Вращающийся светящийся шар с тремя кольцами - магический лоадер
class MagicLoadingSphere extends StatefulWidget {
  final double size;
  final String? message;

  const MagicLoadingSphere({
    super.key,
    this.size = 80,
    this.message,
  });

  @override
  State<MagicLoadingSphere> createState() => _MagicLoadingSphereState();
}

class _MagicLoadingSphereState extends State<MagicLoadingSphere>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _colorController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    // Контроллер для вращения сферы
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // Контроллер для пульсации
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Контроллер для смены цвета
    _colorController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _colorAnimation = ColorTween(
      begin: AppThemeMagic.primaryColor,
      end: AppThemeMagic.secondaryColor,
    ).animate(
      CurvedAnimation(parent: _colorController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([
            _rotationAnimation,
            _pulseAnimation,
            _colorAnimation,
          ]),
          builder: (context, child) {
            final color = _colorAnimation.value ?? AppThemeMagic.primaryColor;
            final pulseValue = _pulseAnimation.value;
            final size = widget.size * pulseValue;

            return Transform.rotate(
              angle: _rotationAnimation.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Внешнее кольцо 1
                  _buildRing(size * 1.3, color.withOpacity(0.2), 0),
                  // Внешнее кольцо 2
                  Transform.rotate(
                    angle: math.pi / 3,
                    child: _buildRing(size * 1.3, color.withOpacity(0.15), math.pi / 6),
                  ),
                  // Внешнее кольцо 3
                  Transform.rotate(
                    angle: -math.pi / 3,
                    child: _buildRing(size * 1.3, color.withOpacity(0.1), -math.pi / 6),
                  ),
                  // Центральная сфера
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color.withOpacity(0.9),
                          color.withOpacity(0.6),
                          color.withOpacity(0.3),
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.6),
                          blurRadius: 20 * pulseValue,
                          spreadRadius: 5 * pulseValue,
                        ),
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 30 * pulseValue,
                          spreadRadius: 2 * pulseValue,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 24),
          Text(
            widget.message!,
            style: (Theme.of(context).textTheme.bodyLarge ?? 
                    const TextStyle(fontSize: 16)).copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildRing(double size, Color color, double rotationOffset) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color,
          width: 2,
        ),
      ),
    );
  }
}

