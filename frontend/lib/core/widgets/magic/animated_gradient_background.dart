import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;
  final bool isDark;

  const AnimatedGradientBackground({
    super.key,
    required this.child,
    this.isDark = true,
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState
    extends State<AnimatedGradientBackground>
    with TickerProviderStateMixin {
  late AnimationController _gradientController1;
  late AnimationController _gradientController2;
  late AnimationController _gradientController3;
  late AnimationController _noiseController;

  @override
  void initState() {
    super.initState();

    _gradientController1 = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();

    _gradientController2 = AnimationController(
      duration: const Duration(seconds: 40),
      vsync: this,
    )..repeat(reverse: true);

    _gradientController3 = AnimationController(
      duration: const Duration(seconds: 35),
      vsync: this,
    )..repeat();

    _noiseController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _gradientController1.dispose();
    _gradientController2.dispose();
    _gradientController3.dispose();
    _noiseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDark) {
      return _buildDarkGradient();
    } else {
      return _buildLightGradient();
    }
  }

  Widget _buildDarkGradient() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _gradientController1,
        _gradientController2,
        _gradientController3,
      ]),
      builder: (context, child) {
        return CustomPaint(
          painter: _MagicGradientPainter(
            progress1: _gradientController1.value,
            progress2: _gradientController2.value,
            progress3: _gradientController3.value,
            isDark: true,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(
                  -0.5 + 0.5 * math.sin(_gradientController1.value * 2 * math.pi),
                  0.3 + 0.3 * math.cos(_gradientController2.value * 2 * math.pi),
                ),
                radius: 1.5,
                colors: [
                  const Color(0xFF1F1147).withOpacity(0.8),
                  const Color(0xFF4A1A7F).withOpacity(0.9),
                  const Color(0xFF1F1147),
                ],
              ),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }

  Widget _buildLightGradient() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _gradientController1,
        _gradientController2,
        _gradientController3,
      ]),
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                -0.4 + 0.4 * math.sin(_gradientController1.value * 2 * math.pi),
                0.4 + 0.4 * math.cos(_gradientController2.value * 2 * math.pi),
              ),
              radius: 1.8,
              colors: [
                const Color(0xFFF5F7FA),
                const Color(0xFFE8ECF1),
                const Color(0xFFDDE4EB),
              ],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _MagicGradientPainter extends CustomPainter {
  final double progress1;
  final double progress2;
  final double progress3;
  final bool isDark;

  _MagicGradientPainter({
    required this.progress1,
    required this.progress2,
    required this.progress3,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [
                const Color(0xFFB794F6).withOpacity(0.15),
                const Color(0xFF6BCAE2).withOpacity(0.1),
                Colors.transparent,
              ]
            : [
                const Color(0xFFB794F6).withOpacity(0.1),
                const Color(0xFFFF6B9D).withOpacity(0.05),
                Colors.transparent,
              ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width * (0.2 + 0.3 * math.sin(progress1 * 2 * math.pi)),
            size.height * (0.3 + 0.2 * math.cos(progress1 * 2 * math.pi)),
          ),
          radius: size.width * 0.6,
        ),
      );

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [
                const Color(0xFFFF6B9D).withOpacity(0.12),
                const Color(0xFFFFA366).withOpacity(0.08),
                Colors.transparent,
              ]
            : [
                const Color(0xFFFFA366).withOpacity(0.08),
                const Color(0xFFFFD93D).withOpacity(0.05),
                Colors.transparent,
              ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width * (0.8 - 0.3 * math.cos(progress2 * 2 * math.pi)),
            size.height * (0.7 - 0.2 * math.sin(progress2 * 2 * math.pi)),
          ),
          radius: size.width * 0.5,
        ),
      );

    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [
                const Color(0xFF6BCAE2).withOpacity(0.1),
                Colors.transparent,
              ]
            : [
                const Color(0xFF6BCAE2).withOpacity(0.06),
                Colors.transparent,
              ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width * 0.5,
            size.height * (0.5 + 0.3 * math.sin(progress3 * 2 * math.pi)),
          ),
          radius: size.width * 0.4,
        ),
      );

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

