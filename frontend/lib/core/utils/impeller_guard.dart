import 'dart:io';
import 'package:flutter/services.dart';

/// ImpellerGuard - автоматически отключает Impeller на проблемных устройствах
/// для предотвращения крашей на Realme/Oppo/Oplus устройствах
class ImpellerGuard {
  /// Отключает Impeller на устройствах Realme/Oppo/Oplus
  static Future<void> disableOnProblemDevices() async {
    if (!Platform.isAndroid) return;

    try {
      final manufacturer = (await _getProp('ro.product.manufacturer')).toLowerCase();
      final brand = (await _getProp('ro.product.brand')).toLowerCase();

      final isProblemDevice = manufacturer.contains('oppo') ||
          manufacturer.contains('realme') ||
          manufacturer.contains('oneplus') ||
          manufacturer.contains('oplus') ||
          brand.contains('oppo') ||
          brand.contains('realme') ||
          brand.contains('oneplus') ||
          brand.contains('oplus');

      if (isProblemDevice) {
        print('[ImpellerGuard] Detected Oplus/Realme/Oppo device, disabling Impeller');
        
        // Попытка отключить через SystemChannels (если доступно)
        try {
          const String disableFlag = 'io.flutter.embedding.android.EnableImpeller';
          await SystemChannels.platform.invokeMethod(
            'SystemNavigator.setFrameworkPreference',
            {disableFlag: false},
          );
        } catch (e) {
          // Fallback: мета-данные в AndroidManifest.xml уже должны отключить Impeller
          print('[ImpellerGuard] SystemChannels method not available, relying on AndroidManifest.xml');
        }
      } else {
        print('[ImpellerGuard] Device is not Oplus/Realme/Oppo, Impeller settings unchanged');
      }
    } catch (e) {
      print('[ImpellerGuard] Error checking device properties: $e');
      // В случае ошибки продолжаем работу - мета-данные в AndroidManifest.xml отключат Impeller
    }
  }

  /// Получает значение системного свойства Android через getprop
  static Future<String> _getProp(String key) async {
    try {
      final result = await Process.run('getprop', [key]);
      return result.stdout.toString().trim();
    } catch (_) {
      return '';
    }
  }
}

