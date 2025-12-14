import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_spacing.dart';

/// Базовый Page компонент с автоматическим фоном и overlay
class AppPage extends StatelessWidget {
  final Widget child;
  final String? backgroundImage;
  final double overlayOpacity;
  final Color? backgroundColor;
  final bool safeArea;

  const AppPage({
    super.key,
    required this.child,
    this.backgroundImage,
    this.overlayOpacity = 0.3,
    this.backgroundColor,
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    if (safeArea) {
      content = SafeArea(child: content);
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      body: Stack(
        children: [
          // Фоновое изображение
          if (backgroundImage != null)
            Positioned.fill(
              child: Image.asset(
                backgroundImage!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.backgroundGradient,
                    ),
                  );
                },
              ),
            )
          else if (backgroundColor == null)
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.backgroundGradient,
              ),
            ),

          // Overlay для читаемости
          if (backgroundImage != null)
            Container(
              color: Colors.black.withOpacity(overlayOpacity),
            ),

          // Контент
          content,
        ],
      ),
    );
  }
}









