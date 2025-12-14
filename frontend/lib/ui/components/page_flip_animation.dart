import 'dart:math' as math;
import 'package:flutter/material.dart';

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
    _controller = AnimationController(
      duration: Duration(milliseconds: (600 / widget.speed).round()),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: widget.angle,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.isFlipped) {
      _controller.value = 1.0;
    }

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFlipComplete?.call();
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
    return GestureDetector(
      onTap: flip,
      child: AnimatedBuilder(
        animation: _rotationAnimation,
        builder: (context, child) {
          final rotation = _rotationAnimation.value;
          final isFlipped = rotation > widget.angle / 2;

          return Transform(
            alignment: Alignment.centerLeft,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Перспектива
              ..rotateY(rotation),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: Offset(math.sin(rotation) * 10, 0),
                  ),
                ],
              ),
              child: isFlipped && widget.backPage != null
                  ? widget.backPage!
                  : widget.frontPage,
            ),
          );
        },
      ),
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

