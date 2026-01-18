import 'package:flutter/material.dart';

/// Универсальный контейнер для десктоп-лейаута.
/// На мобильных возвращает child без изменений.
class DesktopContainer extends StatelessWidget {
  const DesktopContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.desktopBreakpoint = 1024,
    this.horizontalPadding = 24,
  });

  /// Контент, который нужно центрировать на desktop.
  final Widget child;

  /// Максимальная ширина контейнера на desktop.
  /// Используйте <= 1200 для обычных страниц или <= 1400 для grid-страниц.
  final double maxWidth;

  /// Ширина экрана, начиная с которой включается desktop-режим.
  final double desktopBreakpoint;

  /// Внутренние отступы по горизонтали.
  final double horizontalPadding;

  /// Конструктор для обычных страниц.
  const DesktopContainer.page({
    super.key,
    required this.child,
    this.desktopBreakpoint = 1024,
    this.horizontalPadding = 24,
  }) : maxWidth = 1200;

  /// Конструктор для grid-страниц (например, книги).
  const DesktopContainer.grid({
    super.key,
    required this.child,
    this.desktopBreakpoint = 1024,
    this.horizontalPadding = 24,
  }) : maxWidth = 1400;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= desktopBreakpoint;

        if (!isDesktop) {
          // На мобильных оставляем текущий лейаут без изменений.
          return child;
        }

        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
