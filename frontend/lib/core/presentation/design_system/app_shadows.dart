import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Тени и glow эффекты
class AppShadows {
  // Soft shadows
  static List<BoxShadow> get soft => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  // Medium shadows
  static List<BoxShadow> get medium => [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  
  // Large shadows
  static List<BoxShadow> get large => [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  
  // Glow эффекты
  static List<BoxShadow> glowPrimary({double opacity = 0.5, double blur = 20, double spread = 2, Color? glowColor}) => [
    BoxShadow(
      color: (glowColor ?? AppColors.primary).withOpacity(opacity),
      blurRadius: blur,
      spreadRadius: spread,
    ),
  ];
  
  static List<BoxShadow> glowSecondary({double opacity = 0.5, double blur = 20, double spread = 2}) => [
    BoxShadow(
      color: AppColors.secondary.withOpacity(opacity),
      blurRadius: blur,
      spreadRadius: spread,
    ),
  ];
  
  static List<BoxShadow> glowAccent({double opacity = 0.5, double blur = 20, double spread = 2}) => [
    BoxShadow(
      color: AppColors.accent.withOpacity(opacity),
      blurRadius: blur,
      spreadRadius: spread,
    ),
  ];
  
  // Комбинированные (shadow + glow)
  static List<BoxShadow> magic({Color? glowColor}) => [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: (glowColor ?? AppColors.primary).withOpacity(0.3),
      blurRadius: 24,
      spreadRadius: 1,
    ),
  ];
  
  // Success glow
  static List<BoxShadow> glowSuccess({double opacity = 0.5}) => [
    BoxShadow(
      color: AppColors.success.withOpacity(opacity),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];
  
  // Error glow
  static List<BoxShadow> glowError({double opacity = 0.5}) => [
    BoxShadow(
      color: AppColors.error.withOpacity(opacity),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];
}









