import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../env/env.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: Env.backendUrl,
    connectTimeout: const Duration(milliseconds: 8000),
    receiveTimeout: const Duration(milliseconds: 60000), // 1 минута для генерации картинок
  ));

  // Добавляем retry interceptor (должен быть первым)
  dio.interceptors.add(RetryInterceptor(dio: dio));
  
  // Логирование ошибок
  dio.interceptors.add(LoggingInterceptor());
  
  // Авторизация
  dio.interceptors.add(AuthInterceptor(ref));

  return dio;
});

class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Duration retryDelay;
  final Dio dio;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 2,
    this.retryDelay = const Duration(milliseconds: 500),
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err) && err.requestOptions.extra['retryCount'] == null) {
      err.requestOptions.extra['retryCount'] = 0;
    }

    final retryCount = (err.requestOptions.extra['retryCount'] as int?) ?? 0;

    if (retryCount < maxRetries && _shouldRetry(err)) {
      err.requestOptions.extra['retryCount'] = retryCount + 1;
      
      print('[API RETRY] Попытка ${retryCount + 1}/$maxRetries для ${err.requestOptions.uri}');
      
      await Future.delayed(retryDelay);
      
      try {
        final response = await dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (e) {
        if (retryCount + 1 >= maxRetries) {
          handler.next(err);
          return;
        }
      }
    }

    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode != null && err.response!.statusCode! >= 500);
  }
}

class LoggingInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('[API ERROR] ${err.message}');
    print('[API ERROR] URL: ${err.requestOptions.uri}');
    if (err.response != null) {
      print('[API ERROR] Status: ${err.response?.statusCode}');
      print('[API ERROR] Response: ${err.response?.data}');
    }
    handler.next(err);
  }
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('[API REQUEST] ${options.method} ${options.uri}');
    handler.next(options);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print('[API RESPONSE] ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }
}

class AuthInterceptor extends Interceptor {
  final Ref ref;

  AuthInterceptor(this.ref);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // Получаем токен напрямую из FlutterSecureStorage, чтобы избежать циклической зависимости
      const storage = FlutterSecureStorage();
      const tokenKey = 'access_token';
      final token = await storage.read(key: tokenKey);
      
      if (token == null) {
        print('[AuthInterceptor] ❌ Токен отсутствует -> ${options.uri}');
      } else {
        // ВАЖНО: полный токен логируем только в debug сборке (в релизе это небезопасно).
        if (kDebugMode) {
          print('[AuthInterceptor] 🔑 TOKEN (FULL): $token');
        } else {
          print('[AuthInterceptor] 🔑 TOKEN: ${token.substring(0, 20)}...');
        }
        print('[AuthInterceptor] Добавлен токен авторизации -> ${options.uri}');
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      print('[AuthInterceptor] Ошибка получения токена: $e');
      // Игнорируем ошибки при получении токена - продолжаем запрос без токена
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 401 - неавторизован, разлогиниваем
    if (err.response?.statusCode == 401) {
      print('[AuthInterceptor] Обнаружена ошибка 401 - пользователь неавторизован');
      try {
        // Удаляем токен напрямую из хранилища, чтобы избежать циклической зависимости
        const storage = FlutterSecureStorage();
        const tokenKey = 'access_token';
        const userIdKey = 'user_id';
        const userEmailKey = 'user_email';
        storage.delete(key: tokenKey);
        storage.delete(key: userIdKey);
        storage.delete(key: userEmailKey);
        print('[AuthInterceptor] Токен удален из хранилища');

        // Уведомляем AuthRepository, чтобы перевести приложение на экран логина
        Future.microtask(() async {
          try {
            await ref.read(authRepositoryProvider).signOut();
          } catch (e) {
            print('[AuthInterceptor] Ошибка при вызове signOut: $e');
          }
        });
      } catch (e) {
        print('[AuthInterceptor] Ошибка при разлогинивании: $e');
        // Игнорируем ошибки при разлогинивании
      }
    }
    // 404 - endpoint не найден, но это не критично для некоторых запросов
    // Не разлогиниваем пользователя
    handler.next(err);
  }
}

