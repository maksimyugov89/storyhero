import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Кастомная кривая для более естественного переворота страницы
/// Имитирует физику переворота: медленный старт, ускорение в середине, замедление в конце
class PageFlipCurve extends Curve {
  @override
  double transform(double t) {
    // Используем комбинацию кривых для более естественного движения
    if (t < 0.5) {
      // Первая половина: медленный старт с ускорением
      return Curves.easeOutCubic.transform(t * 2) * 0.5;
    } else {
      // Вторая половина: замедление к концу
      return 0.5 + Curves.easeInCubic.transform((t - 0.5) * 2) * 0.5;
    }
  }
}

/// Анимация физического переворота страницы
class PageFlipAnimation extends StatefulWidget {
  final Widget frontPage;
  final Widget? backPage;
  final double speed; // Скорость переворота (1.0 = нормальная)
  final double angle; // Максимальный угол поворота (в радианах)
  final VoidCallback? onFlipComplete;
  final bool isFlipped;
  final bool animated;

  const PageFlipAnimation({
    super.key,
    required this.frontPage,
    this.backPage,
    this.speed = 1.0,
    this.angle = math.pi / 2,
    this.onFlipComplete,
    this.isFlipped = false,
    this.animated = true,
  });

  @override
  State<PageFlipAnimation> createState() => _PageFlipAnimationState();
}

class _PageFlipAnimationState extends State<PageFlipAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    // Увеличиваем длительность для более плавной анимации
    _controller = AnimationController(
      duration: Duration(milliseconds: (800 / widget.speed).round()),
      vsync: this,
    );

    // Используем кастомную кривую для более естественного движения
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: widget.angle,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: PageFlipCurve(), // Используем кастомную кривую
    ));

    if (widget.isFlipped) {
      _controller.value = 1.0;
    }

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Вызываем callback после небольшой задержки, чтобы анимация визуально завершилась
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            widget.onFlipComplete?.call();
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(PageFlipAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.animated) {
        if (widget.isFlipped) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
      } else {
        _controller.value = widget.isFlipped ? 1.0 : 0.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void flip() {
    if (_controller.isCompleted) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        final rotation = _rotationAnimation.value;
        final isFlipped = rotation > widget.angle / 2;
        
        // Вычисляем прогресс анимации (0.0 - 1.0)
        final progress = rotation / widget.angle;
        
        // Динамическая перспектива - увеличивается при перевороте
        final perspective = 0.0008 + (progress * 0.0004);
        
        // Динамические тени - более интенсивные в середине переворота
        final shadowIntensity = math.sin(progress * math.pi);
        final shadowOffset = math.sin(rotation) * 15;
        final shadowBlur = 15 + (shadowIntensity * 25);
        
        // Эффект изгиба страницы (небольшой масштаб по X)
        final scaleX = 1.0 - (math.sin(progress * math.pi) * 0.05);
        
        // Градиент освещения на переворачивающейся странице
        final lightIntensity = math.cos(rotation);
        
        return Transform(
          alignment: Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, perspective) // Улучшенная перспектива
            ..scale(scaleX, 1.0) // Небольшой изгиб страницы
            ..rotateY(rotation),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              boxShadow: [
                // Основная тень от страницы
                BoxShadow(
                  color: Colors.black.withOpacity(0.2 + shadowIntensity * 0.3),
                  blurRadius: shadowBlur,
                  spreadRadius: shadowIntensity * 2,
                  offset: Offset(shadowOffset, 0),
                ),
                // Дополнительная мягкая тень для глубины
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: shadowBlur * 1.5,
                  spreadRadius: -shadowIntensity * 3,
                  offset: Offset(shadowOffset * 0.5, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Основной контент страницы
                Positioned.fill(
                  child: isFlipped && widget.backPage != null
                      ? widget.backPage!
                      : widget.frontPage,
                ),
                // Эффект освещения (градиент) на переворачивающейся странице
                if (progress > 0.1 && progress < 0.9)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white.withOpacity(
                                (lightIntensity * 0.15).clamp(0.0, 0.15),
                              ),
                              Colors.transparent,
                              Colors.black.withOpacity(
                                ((-lightIntensity * 0.1).clamp(0.0, 0.1)),
                              ),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Виджет-обёртка для страницы книги с эффектом тени
class BookPage extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const BookPage({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ??
        (isDark
            ? const Color(0xFF2A1F5C)
            : Colors.white);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }
}

