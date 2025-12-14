import 'package:flutter/material.dart';

/// Цветовая палитра приложения StoryHero
class AppColors {
  // Primary (Магический фиолетовый)
  static const Color primary = Color(0xFF9B5EFF);
  static const Color primaryVariant = Color(0xFF7B3FE0);
  static const Color primaryLight = Color(0xFFB794F6);
  static const Color primaryDark = Color(0xFF6B2FD0);
  
  // Secondary (Розовый)
  static const Color secondary = Color(0xFFF277E6);
  static const Color secondaryVariant = Color(0xFFE055D0);
  
  // Tertiary (Голубой)
  static const Color tertiary = Color(0xFF6BCAE2);
  
  // Accent (Золотой)
  static const Color accent = Color(0xFFFFD93D);
  static const Color accentOrange = Color(0xFFFFA366);
  
  // Background
  static const Color background = Color(0xFF1F1147);
  static const Color backgroundVariant = Color(0xFF2A1F5C);
  static const Color surface = Color(0xFF3A2F6C);
  static const Color surfaceVariant = Color(0xFF4A3F7C);
  
  // Text
  static const Color onPrimary = Colors.white;
  static const Color onSecondary = Colors.white;
  static const Color onBackground = Colors.white;
  static const Color onSurface = Colors.white;
  static const Color onSurfaceVariant = Color(0xFFB8B8D1);
  
  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF42A5F5);
  
  // Glow эффекты
  static Color get glowPrimary => primary.withOpacity(0.5);
  static Color get glowSecondary => secondary.withOpacity(0.5);
  static Color get glowAccent => accent.withOpacity(0.5);
  
  // Градиенты
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, backgroundVariant],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient magicGradient = LinearGradient(
    colors: [primary, secondary, tertiary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

