import 'package:flutter/material.dart';

/// Безопасная функция для получения валидного fontSize
/// Гарантирует, что fontSize всегда конечное число (не null, не NaN, не infinity)
double safeFontSize(double? fontSize, {double defaultValue = 16.0}) {
  if (fontSize == null) return defaultValue;
  if (fontSize.isNaN || fontSize.isInfinite || fontSize <= 0) {
    return defaultValue;
  }
  return fontSize;
}

/// Безопасное создание TextStyle с гарантированно валидным fontSize
TextStyle safeTextStyle({
  double? fontSize,
  double defaultFontSize = 16.0,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
  TextDecoration? decoration,
  Color? decorationColor,
  TextStyle? baseStyle,
}) {
  final safeSize = safeFontSize(fontSize ?? baseStyle?.fontSize, defaultValue: defaultFontSize);
  
  final style = baseStyle ?? const TextStyle();
  
  return style.copyWith(
    fontSize: safeSize,
    fontWeight: fontWeight ?? style.fontWeight,
    color: color ?? style.color,
    height: height ?? style.height,
    letterSpacing: letterSpacing ?? style.letterSpacing,
    decoration: decoration ?? style.decoration,
    decorationColor: decorationColor ?? style.decorationColor,
  );
}

/// Безопасное копирование TextStyle с гарантией валидного fontSize
TextStyle safeCopyWith(TextStyle? style, {
  double? fontSize,
  double defaultFontSize = 16.0,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
  TextDecoration? decoration,
  Color? decorationColor,
}) {
  if (style == null) {
    return TextStyle(
      fontSize: safeFontSize(fontSize, defaultValue: defaultFontSize),
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }
  
  final safeSize = safeFontSize(
    fontSize ?? style.fontSize,
    defaultValue: defaultFontSize,
  );
  
  return style.copyWith(
    fontSize: safeSize,
    fontWeight: fontWeight ?? style.fontWeight,
    color: color ?? style.color,
    height: height ?? style.height,
    letterSpacing: letterSpacing ?? style.letterSpacing,
    decoration: decoration ?? style.decoration,
    decorationColor: decorationColor ?? style.decorationColor,
  );
}

