import 'package:flutter/material.dart';

/// Система отступов (8px grid)
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
  
  // Padding
  static const EdgeInsets paddingXS = EdgeInsets.all(xs);
  static const EdgeInsets paddingSM = EdgeInsets.all(sm);
  static const EdgeInsets paddingMD = EdgeInsets.all(md);
  static const EdgeInsets paddingLG = EdgeInsets.all(lg);
  static const EdgeInsets paddingXL = EdgeInsets.all(xl);
  
  // Horizontal
  static const EdgeInsets paddingHMD = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHLG = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets paddingHXL = EdgeInsets.symmetric(horizontal: xl);
  
  // Vertical
  static const EdgeInsets paddingVMD = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets paddingVLG = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets paddingVXL = EdgeInsets.symmetric(vertical: xl);
  
  // Symmetric
  static EdgeInsets symmetric({
    double? horizontal,
    double? vertical,
  }) {
    return EdgeInsets.symmetric(
      horizontal: horizontal ?? 0,
      vertical: vertical ?? 0,
    );
  }
}









