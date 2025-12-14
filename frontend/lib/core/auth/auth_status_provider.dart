import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'auth_status.dart';

/// Единый источник истины для состояния авторизации
/// Используется во всем приложении для проверки статуса авторизации
final authStatusProvider = StateProvider<AuthStatus>((ref) {
  return AuthStatus.unknown; // Начальное состояние - еще не проверили токен
});

