import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Сервис защиты от скриншотов
/// 
/// Использует несколько методов защиты:
/// 1. FLAG_SECURE на Android (запрет скриншотов)
/// 2. Водяные знаки на изображениях
/// 3. Размытие для неоплаченного контента
class ScreenshotProtectionService {
  static const _channel = MethodChannel('screenshot_protection');
  
  /// Включить защиту от скриншотов (Android)
  static Future<void> enableProtection() async {
    try {
      await _channel.invokeMethod('enableSecureFlag');
    } catch (e) {
      // Ignore - может не поддерживаться на платформе
      debugPrint('[ScreenshotProtection] Не удалось включить защиту: $e');
    }
  }
  
  /// Выключить защиту от скриншотов
  static Future<void> disableProtection() async {
    try {
      await _channel.invokeMethod('disableSecureFlag');
    } catch (e) {
      debugPrint('[ScreenshotProtection] Не удалось выключить защиту: $e');
    }
  }
}

/// Виджет водяного знака для защиты контента
class WatermarkOverlay extends StatelessWidget {
  final Widget child;
  final String watermarkText;
  final bool showWatermark;
  final double opacity;
  
  const WatermarkOverlay({
    super.key,
    required this.child,
    this.watermarkText = 'ПРЕВЬЮ • StoryHero',
    this.showWatermark = true,
    this.opacity = 0.15,
  });

  @override
  Widget build(BuildContext context) {
    if (!showWatermark) return child;
    
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: WatermarkPainter(
                text: watermarkText,
                opacity: opacity,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Рисует диагональный водяной знак
class WatermarkPainter extends CustomPainter {
  final String text;
  final double opacity;
  
  WatermarkPainter({
    required this.text,
    this.opacity = 0.15,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: Colors.white.withOpacity(opacity),
      fontSize: 24,
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
    );
    
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Рисуем водяной знак по диагонали несколько раз
    canvas.save();
    canvas.rotate(-0.4); // ~-23 градуса
    
    final stepX = textPainter.width + 80;
    final stepY = textPainter.height + 100;
    
    for (double y = -size.height; y < size.height * 2; y += stepY) {
      for (double x = -size.width; x < size.width * 2; x += stepX) {
        textPainter.paint(canvas, Offset(x, y));
      }
    }
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(WatermarkPainter oldDelegate) {
    return text != oldDelegate.text || opacity != oldDelegate.opacity;
  }
}

/// Виджет размытия для неоплаченного контента
class BlurredPreview extends StatelessWidget {
  final Widget child;
  final bool isBlurred;
  final double blurAmount;
  final String? message;
  
  const BlurredPreview({
    super.key,
    required this.child,
    this.isBlurred = true,
    this.blurAmount = 8.0,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    if (!isBlurred) return child;
    
    return Stack(
      children: [
        // Размытый контент
        ImageFiltered(
          imageFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.3),
            BlendMode.darken,
          ),
          child: child,
        ),
        // Сообщение поверх
        if (message != null)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.5),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        color: Colors.amber,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Виджет защищенного превью книги
class ProtectedBookPreview extends StatelessWidget {
  final Widget child;
  final bool isPaid;
  final bool isPreview;
  
  const ProtectedBookPreview({
    super.key,
    required this.child,
    this.isPaid = false,
    this.isPreview = true,
  });

  @override
  Widget build(BuildContext context) {
    // Если оплачено - показываем без защиты
    if (isPaid) return child;
    
    // Для превью добавляем водяной знак и ограничения
    return WatermarkOverlay(
      showWatermark: isPreview && !isPaid,
      child: child,
    );
  }
}

