import 'package:flutter/material.dart';

/// Безопасная функция для получения валидного fontSize
/// Гарантирует, что fontSize всегда конечное число (не null, не NaN, не infinity)
/// ВАЖНО: clamp вызывается ПОСЛЕ валидации, так как (NaN).clamp() возвращает NaN
double safeFontSize(double? fontSize, {double defaultValue = 16.0, double min = 8.0, double max = 200.0}) {
  if (fontSize == null || !fontSize.isFinite || fontSize <= 0) {
    return defaultValue;
  }
  
  final clamped = fontSize.clamp(min, max);
  if (!clamped.isFinite || clamped <= 0) {
    return defaultValue;
  }
  
  return clamped;
}

/// Безопасное создание TextStyle с гарантированно валидным fontSize
TextStyle safeTextStyle({
  double? fontSize,
  double defaultFontSize = 16.0,
  double minFontSize = 8.0,
  double maxFontSize = 200.0,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
  TextDecoration? decoration,
  Color? decorationColor,
  TextStyle? baseStyle,
}) {
  final rawSize = fontSize ?? baseStyle?.fontSize;
  if (rawSize == null || !rawSize.isFinite || rawSize <= 0) {
    final safeSize = safeFontSize(defaultFontSize, defaultValue: defaultFontSize, min: minFontSize, max: maxFontSize);
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
  
  final safeSize = safeFontSize(rawSize, defaultValue: defaultFontSize, min: minFontSize, max: maxFontSize);
  
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
  double minFontSize = 8.0,
  double maxFontSize = 200.0,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
  TextDecoration? decoration,
  Color? decorationColor,
}) {
  if (style == null) {
    final safeSize = safeFontSize(fontSize, defaultValue: defaultFontSize, min: minFontSize, max: maxFontSize);
    return TextStyle(
      fontSize: safeSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }
  
  final rawSize = fontSize ?? style.fontSize;
  final safeSize = safeFontSize(
    rawSize,
    defaultValue: defaultFontSize,
    min: minFontSize,
    max: maxFontSize,
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

