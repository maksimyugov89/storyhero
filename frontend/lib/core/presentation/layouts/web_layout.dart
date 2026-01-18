import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Breakpoints для адаптивного дизайна на Web
class WebBreakpoints {
  static const double tablet = 900;
  static const double desktop = 1280;
  static const double wideDesktop = 1440;

  /// Определяет текущий breakpoint на основе ширины экрана
  static Breakpoint getBreakpoint(double width) {
    if (width < tablet) return Breakpoint.tablet;
    if (width < desktop) return Breakpoint.desktop;
    return Breakpoint.wideDesktop;
  }

  /// Количество колонок для сетки книг/детей
  static int gridColumns(double width) {
    final breakpoint = getBreakpoint(width);
    switch (breakpoint) {
      case Breakpoint.tablet:
        return 2;
      case Breakpoint.desktop:
        return 3;
      case Breakpoint.wideDesktop:
        return 4;
    }
  }

  /// Максимальная ширина контента
  static double maxContentWidth(double width) {
    final breakpoint = getBreakpoint(width);
    switch (breakpoint) {
      case Breakpoint.tablet:
        return 800;
      case Breakpoint.desktop:
        return 1200;
      case Breakpoint.wideDesktop:
        return 1400;
    }
  }

  /// Отступы по бокам
  static double sidePadding(double width) {
    final breakpoint = getBreakpoint(width);
    switch (breakpoint) {
      case Breakpoint.tablet:
        return 24;
      case Breakpoint.desktop:
        return 32;
      case Breakpoint.wideDesktop:
        return 48;
    }
  }
}

enum Breakpoint { tablet, desktop, wideDesktop }

/// Общий layout для Web-версии, который центрирует контент и ограничивает ширину
class WebLayout extends StatelessWidget {
  final Widget child;
  final bool enableConstraints;
  final double? maxWidth;
  final EdgeInsets? padding;

  const WebLayout({
    super.key,
    required this.child,
    this.enableConstraints = true,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    // Если не Web или отключены ограничения, возвращаем child как есть
    if (!kIsWeb || !enableConstraints) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final double effectiveMaxWidth = maxWidth ?? WebBreakpoints.maxContentWidth(width);
        final double sidePaddingValue = padding?.horizontal ?? WebBreakpoints.sidePadding(width);

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: effectiveMaxWidth,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: sidePaddingValue),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Обёртка для карточек с hover-эффектами (только для Web)
class WebCardWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;

  const WebCardWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadiusValue = borderRadius ?? BorderRadius.circular(16);
    final paddingValue = padding ?? const EdgeInsets.all(16);

    Widget content = Container(
      decoration: BoxDecoration(
        borderRadius: borderRadiusValue,
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadiusValue,
        child: Padding(
          padding: paddingValue,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: content,
        ),
      );
    }

    // Добавляем hover-эффект только на Web
    if (kIsWeb && onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: content,
          transform: Matrix4.identity(),
          transformAlignment: Alignment.center,
          onEnd: () {},
        ),
      );
    }

    return content;
  }
}

/// Сетка для отображения карточек (книги, дети) с адаптивным количеством колонок
class WebResponsiveGrid extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  const WebResponsiveGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.childAspectRatio = 0.72,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = WebBreakpoints.gridColumns(width);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
          ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}