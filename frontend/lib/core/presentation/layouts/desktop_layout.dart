import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import '../../widgets/magic/fade_slide.dart';

/// Production‑grade breakpoints для desktop‑first и 4K
/// Соответствует требованиям: mobile (<600), tablet (600–1024), desktop (1024–1440), large desktop (1440–2560), 4K (2560+)
class DesktopBreakpoints {
  static const double tablet = 600; // минимальная ширина tablet
  static const double desktop = 1024; // минимальная ширина desktop
  static const double largeDesktop = 1440; // минимальная ширина large desktop
  static const double ultraWide = 2560; // 4K и сверхширокие мониторы

  /// Определяет текущий уровень на основе ширины экрана
  static DesktopLayoutLevel getLevel(double width) {
    if (width < tablet) return DesktopLayoutLevel.mobile;
    if (width < desktop) return DesktopLayoutLevel.tablet;
    if (width < largeDesktop) return DesktopLayoutLevel.desktop;
    if (width < ultraWide) return DesktopLayoutLevel.largeDesktop;
    return DesktopLayoutLevel.ultraWide;
  }

  /// Максимальная ширина контента для каждого уровня
  static double maxContentWidth(double width) {
    final level = getLevel(width);
    switch (level) {
      case DesktopLayoutLevel.mobile:
        return double.infinity; // на mobile нет ограничений по ширине
      case DesktopLayoutLevel.tablet:
        return 800;
      case DesktopLayoutLevel.desktop:
        return 1440;
      case DesktopLayoutLevel.largeDesktop:
        return 1600;
      case DesktopLayoutLevel.ultraWide:
        return 1920; // на 4K оставляем комфортную ширину, не растягиваем
    }
  }

  /// Боковые отступы (padding) для контента
  static double sidePadding(double width) {
    final level = getLevel(width);
    switch (level) {
      case DesktopLayoutLevel.mobile:
        return 16;
      case DesktopLayoutLevel.tablet:
        return 24;
      case DesktopLayoutLevel.desktop:
        return 48;
      case DesktopLayoutLevel.largeDesktop:
        return 64;
      case DesktopLayoutLevel.ultraWide:
        return 96; // на широких экранах больше воздуха
    }
  }

  /// Количество колонок в сетке для карточек (книги, дети)
  static int gridColumns(double width) {
    final level = getLevel(width);
    switch (level) {
      case DesktopLayoutLevel.mobile:
        return 1;
      case DesktopLayoutLevel.tablet:
        return 2;
      case DesktopLayoutLevel.desktop:
        return 3;
      case DesktopLayoutLevel.largeDesktop:
        return 4;
      case DesktopLayoutLevel.ultraWide:
        return 5; // на 4K можно 5 колонок
    }
  }

  /// Размер шкалы типографики (scale factor)
  static double typographyScale(double width) {
    final level = getLevel(width);
    switch (level) {
      case DesktopLayoutLevel.mobile:
        return 0.9;
      case DesktopLayoutLevel.tablet:
        return 1.0;
      case DesktopLayoutLevel.desktop:
        return 1.1;
      case DesktopLayoutLevel.largeDesktop:
        return 1.2;
      case DesktopLayoutLevel.ultraWide:
        return 1.3;
    }
  }
}

enum DesktopLayoutLevel { mobile, tablet, desktop, largeDesktop, ultraWide }

/// Основной layout‑контейнер для desktop‑first веб‑интерфейса.
/// Центрирует контент, ограничивает максимальную ширину, добавляет адаптивные отступы.
/// Автоматически применяется только на Web (kIsWeb).
class DesktopLayout extends StatelessWidget {
  final Widget child;
  final bool enableConstraints;
  final double? maxWidth;
  final EdgeInsets? padding;
  final bool applyBackgroundOverlay;
  final bool enableEnterAnimation;

  const DesktopLayout({
    super.key,
    required this.child,
    this.enableConstraints = true,
    this.maxWidth,
    this.padding,
    this.applyBackgroundOverlay = false,
    this.enableEnterAnimation = true,
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
        final double effectiveMaxWidth = maxWidth ?? DesktopBreakpoints.maxContentWidth(width);
        final double sidePaddingValue = padding?.horizontal ?? DesktopBreakpoints.sidePadding(width);

        Widget content = Center(
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

        // Наложение overlay для улучшения читаемости на декоративных фонах
        if (applyBackgroundOverlay) {
          content = Stack(
            children: [
              // Overlay под контентом, игнорирующий указатели
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.02),
                          Colors.black.withOpacity(0.05),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Контент поверх overlay
              content,
            ],
          );
        }

        // Анимация появления (только для Web)
        if (enableEnterAnimation && kIsWeb) {
          return FadeSlide(
            child: content,
            offset: 20,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
          );
        }
        return content;
      },
    );
  }
}

/// Специализированный Scaffold для desktop‑экранов.
/// Включает AppBar, Hero‑секцию, основной контент и футер.
class DesktopScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? hero;
  final Widget body;
  final Widget? footer;
  final bool centerContent;
  final Color? backgroundColor;
  final String? backgroundImage;

  const DesktopScaffold({
    super.key,
    this.appBar,
    this.hero,
    required this.body,
    this.footer,
    this.centerContent = true,
    this.backgroundColor,
    this.backgroundImage,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (appBar != null) appBar!,
        if (hero != null) hero!,
        Expanded(
          child: body,
        ),
        if (footer != null) footer!,
      ],
    );

    if (centerContent) {
      content = DesktopLayout(
        enableConstraints: kIsWeb,
        child: content,
      );
    }

    // Фон с возможностью наложения blur/overlay
    Widget scaffold = Container(
      color: backgroundColor ?? Theme.of(context).colorScheme.background,
      child: content,
    );

    if (backgroundImage != null) {
      scaffold = Stack(
        children: [
          // Декоративный фон (картинка)
          Positioned.fill(
            child: Image.asset(
              backgroundImage!,
              fit: BoxFit.cover,
            ),
          ),
          // Overlay для читаемости
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.5),
                  ],
                ),
              ),
            ),
          ),
          // Контент поверх
          scaffold,
        ],
      );
    }

    return scaffold;
  }
}

/// Контейнер для форм и кнопок, ограничивающий ширину до комфортного значения (420–520px)
/// и центрирующий содержимое. Применяется только на Web.
class DesktopFormContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;

  const DesktopFormContainer({
    super.key,
    required this.child,
    this.maxWidth = 520,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    // На мобильных устройствах не ограничиваем ширину
    if (!kIsWeb) {
      return child;
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
    );
  }
}

/// Контейнер для контента с glass‑morphism эффектом (для поверх фонов).
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final double blurStrength;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.blurStrength = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurStrength, sigmaY: blurStrength),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Адаптивная сетка для desktop с поддержкой 4K и hover‑эффектами.
class DesktopResponsiveGrid extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final bool enableHover;

  const DesktopResponsiveGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.childAspectRatio = 0.85,
    this.crossAxisSpacing = 24,
    this.mainAxisSpacing = 24,
    this.enableHover = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = DesktopBreakpoints.gridColumns(width);
        if (kDebugMode && kIsWeb) {
          print('[DesktopResponsiveGrid] width=$width, columns=$columns, itemCount=$itemCount');
        }

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
          itemBuilder: (context, index) {
            final child = itemBuilder(context, index);
            if (!enableHover || !kIsWeb) return child;

            // Добавляем hover‑эффект с анимацией
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: child,
              ),
            );
          },
        );
      },
    );
  }
}

/// Desktop‑stepper для многошаговых форм (например, создание книги).
class DesktopStepper extends StatelessWidget {
  final int currentStep;
  final List<String> steps;
  final EdgeInsets margin;

  const DesktopStepper({
    super.key,
    required this.currentStep,
    required this.steps,
    this.margin = const EdgeInsets.symmetric(vertical: 40),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final label = entry.value;
          final isActive = index == currentStep;
          final isCompleted = index < currentStep;

          return Expanded(
            child: Column(
              children: [
                // Линия‑соединитель слева
                if (index > 0)
                  Container(
                    height: 2,
                    color: isCompleted || isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceVariant,
                  ),
                // Круг шага
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Theme.of(context).colorScheme.primary
                        : isActive
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                            : Theme.of(context).colorScheme.surfaceVariant,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                        : Text(
                            '${index + 1}',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                  ),
                ),
                // Подпись шага
                const SizedBox(height: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}