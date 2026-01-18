import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 1024;
    final baseOverlay = (overlayOpacity + (isWide ? 0.12 : 0.0))
        .clamp(0.0, 0.7);
    final overlayTop = (baseOverlay + 0.12).clamp(0.0, 0.75);
    final overlayBottom = (baseOverlay - 0.08).clamp(0.0, 0.6);

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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withOpacity(overlayTop),
                    Colors.black.withOpacity(overlayBottom),
                  ],
                ),
              ),
            ),

          // Контент
          content,
        ],
      ),
    );
  }
}









