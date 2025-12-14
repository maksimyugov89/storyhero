import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app.dart';
import 'core/utils/impeller_guard.dart';
import 'core/auth/auth_status.dart';
import 'core/auth/auth_status_provider.dart';

const _storage = FlutterSecureStorage();
const _tokenKey = 'access_token';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Отключаем Impeller для предотвращения крашей на Realme/Oppo/Oplus устройствах
  // Основной способ отключения - через мета-данные в AndroidManifest.xml
  // ImpellerGuard дополнительно проверяет устройство и логирует информацию
  try {
    await ImpellerGuard.disableOnProblemDevices();
  } catch (e) {
    print('[main] Error disabling Impeller: $e');
    // Продолжаем работу - мета-данные в AndroidManifest.xml отключат Impeller
  }

  // Проверяем наличие сохраненного токена при старте
  AuthStatus initialAuthStatus = AuthStatus.unknown;
  try {
    final token = await _storage.read(key: _tokenKey);
    if (token != null && token.isNotEmpty) {
      initialAuthStatus = AuthStatus.authenticated;
      print('[main] Проверка токена при старте: найден');
    } else {
      initialAuthStatus = AuthStatus.unauthenticated;
      print('[main] Проверка токена при старте: не найден');
    }
  } catch (e) {
    print('[main] Ошибка проверки токена: $e');
    initialAuthStatus = AuthStatus.unauthenticated;
  }

  print('[main] ✅ Приложение инициализировано (кастомная авторизация)');

  // Запускаем приложение с начальным состоянием авторизации
  runApp(
    ProviderScope(
      overrides: [
        // Устанавливаем начальное состояние авторизации
        authStatusProvider.overrideWith((ref) => initialAuthStatus),
      ],
      child: const App(),
    ),
  );
}
