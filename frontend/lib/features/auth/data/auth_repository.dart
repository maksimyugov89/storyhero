import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/user.dart' as app_models;
import '../../../core/auth/auth_status.dart';
import '../../../core/auth/auth_status_provider.dart';
import '../../../core/storage/storage_service.dart';

const _tokenKey = 'access_token';
const _userIdKey = 'user_id';
const _userEmailKey = 'user_email';

/// Безопасное получение строки из Map
String? _safeGetString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

/// Безопасное преобразование значения в String (обрабатывает int, String и другие типы)
String? _safeConvertToString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is int) return value.toString();
  if (value is num) return value.toString();
  return value.toString();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio, ref);
});

class AuthRepository {
  final Dio _dio;
  final Ref _ref;
  final StreamController<bool> _authStateController = StreamController<bool>.broadcast();

  AuthRepository(this._dio, this._ref) {
    // Проверяем наличие токена при инициализации
    _checkAuthState();
  }

  /// Проверяет наличие токена и обновляет состояние авторизации
  Future<void> _checkAuthState() async {
    final token = await StorageService.read(_tokenKey);
    final hasToken = token != null && token.isNotEmpty;
    
    // Обновляем единый источник истины
    _ref.read(authStatusProvider.notifier).state = hasToken 
        ? AuthStatus.authenticated 
        : AuthStatus.unauthenticated;
    
    // Эмитим в stream для обратной совместимости
    _authStateController.add(hasToken);
  }

  /// Вход через POST /auth/login
  Future<app_models.User?> signIn(String email, String password) async {
    try {
      print('[AuthRepository] signIn: Попытка входа для $email');
      
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email, // Бэкенд ожидает email, а не username
          'password': password,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        print('[AuthRepository] signIn: Ответ сервера: $data');
        
        try {
          // Проверяем разные возможные форматы ответа с безопасным преобразованием типов
          final accessToken = _safeGetString(data, 'access_token') ?? 
                            _safeGetString(data, 'token');
          
          // Безопасное преобразование userId (может быть int или String)
          final userIdValue = data['user_id'] ?? data['id'];
          final userIdStr = _safeConvertToString(userIdValue) ?? email;
          
          final userEmail = _safeGetString(data, 'email') ?? email;

          if (accessToken == null) {
            print('[AuthRepository] signIn: Токен отсутствует в ответе. Доступные ключи: ${data.keys.toList()}');
            throw Exception('Токен не получен от сервера');
          }

          // Сохраняем токен и данные пользователя
          await StorageService.write(_tokenKey, accessToken);
          await StorageService.write(_userIdKey, userIdStr);
          await StorageService.write(_userEmailKey, userEmail);

          print('[AuthRepository] signIn: Успешный вход, токен сохранен');
          
          // Обновляем единый источник истины
          _ref.read(authStatusProvider.notifier).state = AuthStatus.authenticated;
          
          // Эмитим событие авторизации в stream для обратной совместимости
          _authStateController.add(true);

          return app_models.User(
            id: userIdStr,
            email: userEmail,
      );
    } catch (e) {
          // Обрабатываем ошибки парсинга данных
          print('[AuthRepository] signIn: Ошибка парсинга ответа: $e');
          throw Exception('Ошибка обработки ответа от сервера. Попробуйте позже.');
    }
  }

      throw Exception('Не удалось войти: статус ${response.statusCode}');
    } on DioException catch (e) {
      print('[AuthRepository] signIn: DioException: ${e.type} - ${e.response?.statusCode}');
      
      // Обрабатываем ошибки от FastAPI (формат: {detail: "..."})
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final responseData = e.response!.data;
        
        print('[AuthRepository] signIn: Обработка ошибки. Status: $statusCode, Data type: ${responseData.runtimeType}');
        
        // Парсим поле detail из ответа
        String errorMessage = 'Ошибка входа';
        
        // Для ошибок сервера (500+) сразу показываем понятное сообщение
        if (statusCode != null && statusCode >= 500) {
          if (statusCode == 502) {
            errorMessage = 'Сервер временно недоступен. Проверьте подключение к интернету и попробуйте позже.';
            print('[AuthRepository] signIn: Ошибка 502 - сервер недоступен');
          } else if (statusCode == 503) {
            errorMessage = 'Сервер перегружен. Попробуйте позже.';
          } else if (statusCode == 504) {
            errorMessage = 'Превышено время ожидания ответа от сервера. Попробуйте позже.';
          } else {
            errorMessage = 'Сервер недоступен. Попробуйте позже.';
          }
        } else if (responseData is Map<String, dynamic> && responseData.containsKey('detail')) {
          final detail = responseData['detail'];
          if (detail is String) {
            errorMessage = detail;
          } else if (detail is List && detail.isNotEmpty) {
            // Если detail - это массив ошибок валидации
            final firstError = detail.first;
            if (firstError is Map<String, dynamic>) {
              // Извлекаем msg из первого элемента массива
              if (firstError.containsKey('msg')) {
                errorMessage = firstError['msg'] as String;
              } else {
                errorMessage = firstError.toString();
    }
            } else {
              errorMessage = firstError.toString();
            }
          } else {
            errorMessage = detail.toString();
          }
        } else if (responseData is String) {
          // Используем строковый ответ как сообщение об ошибке
          // Проверяем, не является ли это HTML (для случаев, когда statusCode < 500)
          final responseStr = responseData.trim().toLowerCase();
          if (responseStr.startsWith('<!doctype') || 
              responseStr.startsWith('<html') ||
              responseStr.contains('<html>')) {
            // Это HTML, но statusCode < 500 - странный случай, используем общее сообщение
            errorMessage = 'Ошибка при обработке ответа сервера';
          } else {
          errorMessage = responseData;
          }
        }
        
        // Преобразуем технические сообщения в понятные для пользователя
        // Не перезаписываем сообщения об ошибках сервера (500+)
        if (statusCode != null && statusCode >= 500) {
          // Сообщение уже установлено выше, не перезаписываем
        } else if (statusCode == 401 || statusCode == 403) {
          errorMessage = 'Неверный email или пароль';
        } else if (statusCode == 400 || statusCode == 422) {
          // Ошибка валидации - преобразуем технические сообщения
          final lowerError = errorMessage.toLowerCase();
          
          if (lowerError.contains('field required') || lowerError.contains('обязательное поле')) {
            if (lowerError.contains('email') || lowerError.contains('username')) {
              errorMessage = 'Введите email';
            } else if (lowerError.contains('password')) {
              errorMessage = 'Введите пароль';
            } else {
              errorMessage = 'Заполните все обязательные поля';
            }
          } else if (lowerError.contains('email') || lowerError.contains('username')) {
            if (lowerError.contains('invalid') || lowerError.contains('некорректный')) {
              errorMessage = 'Некорректный email';
            } else if (lowerError.contains('already exists') || lowerError.contains('уже существует')) {
              errorMessage = 'Пользователь с таким email уже существует';
            } else {
              errorMessage = 'Ошибка в email';
            }
          } else if (lowerError.contains('password')) {
            if (lowerError.contains('short') || lowerError.contains('короткий')) {
              errorMessage = 'Пароль должен быть не менее 6 символов';
            } else if (lowerError.contains('weak') || lowerError.contains('слабый')) {
              errorMessage = 'Пароль слишком слабый';
            } else {
              errorMessage = 'Ошибка в пароле';
            }
          } else if (lowerError.contains('credentials') || lowerError.contains('неверный')) {
            errorMessage = 'Неверный email или пароль';
    }
        } else if (statusCode == 404) {
          errorMessage = 'Сервер не найден. Проверьте настройки подключения.';
        }
        
        throw Exception(errorMessage);
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout ||
                 e.type == DioExceptionType.sendTimeout) {
        throw Exception('Превышено время ожидания. Проверьте подключение к интернету.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Сервер недоступен. Проверьте подключение к интернету.');
      } else {
        throw Exception('Ошибка подключения: ${e.message ?? "Неизвестная ошибка"}');
  }
    } catch (e) {
      print('[AuthRepository] signIn: Ошибка входа: $e');
      
      // Обрабатываем ошибки приведения типов и парсинга
      if (e.toString().contains('is not a subtype') || 
          e.toString().contains('type cast') ||
          e.toString().contains('TypeError')) {
        throw Exception('Ошибка обработки данных от сервера. Попробуйте позже.');
  }

      rethrow;
    }
  }

  /// Регистрация через POST /auth/register
  Future<app_models.User?> signUp(String email, String password) async {
    try {
      print('[AuthRepository] signUp: Попытка регистрации для $email');
      
      final response = await _dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        print('[AuthRepository] signUp: Ответ сервера: $data');
        
        try {
          // Проверяем разные возможные форматы ответа с безопасным преобразованием типов
          final accessToken = _safeGetString(data, 'access_token') ?? 
                            _safeGetString(data, 'token');
          
          // Безопасное преобразование userId (может быть int или String)
          final userIdValue = data['user_id'] ?? data['id'];
          final userIdStr = _safeConvertToString(userIdValue) ?? email;
          
          final userEmail = _safeGetString(data, 'email') ?? email;
      
          if (accessToken == null) {
            print('[AuthRepository] signUp: Токен отсутствует в ответе. Доступные ключи: ${data.keys.toList()}');
            throw Exception('Токен не получен от сервера');
      }
      
          // Сохраняем токен и данные пользователя
          await StorageService.write(_tokenKey, accessToken);
          await StorageService.write(_userIdKey, userIdStr);
          await StorageService.write(_userEmailKey, userEmail);

          print('[AuthRepository] signUp: Успешная регистрация, токен сохранен');
          
          // Обновляем единый источник истины
          _ref.read(authStatusProvider.notifier).state = AuthStatus.authenticated;
          
          // Эмитим событие авторизации в stream для обратной совместимости
          _authStateController.add(true);

          return app_models.User(
            id: userIdStr,
            email: userEmail,
          );
        } catch (e) {
          // Обрабатываем ошибки парсинга данных
          print('[AuthRepository] signUp: Ошибка парсинга ответа: $e');
          throw Exception('Ошибка обработки ответа от сервера. Попробуйте позже.');
        }
      }
      
      throw Exception('Не удалось зарегистрироваться: статус ${response.statusCode}');
    } on DioException catch (e) {
      print('[AuthRepository] signUp: DioException: ${e.type} - ${e.response?.statusCode}');
      
      // Обрабатываем ошибки от FastAPI (формат: {detail: "..."})
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final responseData = e.response!.data;
        
        // Парсим поле detail из ответа
        String errorMessage = 'Ошибка регистрации';
        if (responseData is Map<String, dynamic> && responseData.containsKey('detail')) {
          final detail = responseData['detail'];
          if (detail is String) {
            errorMessage = detail;
          } else if (detail is List && detail.isNotEmpty) {
            // Если detail - это массив ошибок валидации
            final firstError = detail.first;
            if (firstError is Map<String, dynamic>) {
              // Извлекаем msg из первого элемента массива
              if (firstError.containsKey('msg')) {
                errorMessage = firstError['msg'] as String;
              } else {
                errorMessage = firstError.toString();
              }
            } else {
              errorMessage = firstError.toString();
            }
          } else {
            errorMessage = detail.toString();
          }
        } else if (responseData is String) {
          errorMessage = responseData;
        }
        
        // Преобразуем технические сообщения в понятные для пользователя
        if (statusCode == 400 || statusCode == 422) {
          // Ошибка валидации - преобразуем технические сообщения
          final lowerError = errorMessage.toLowerCase();
          
          if (lowerError.contains('field required') || lowerError.contains('обязательное поле')) {
            if (lowerError.contains('email') || lowerError.contains('username')) {
              errorMessage = 'Введите email';
            } else if (lowerError.contains('password')) {
              errorMessage = 'Введите пароль';
            } else {
              errorMessage = 'Заполните все обязательные поля';
            }
          } else if (lowerError.contains('email') || lowerError.contains('username')) {
            if (lowerError.contains('already exists') || 
                lowerError.contains('уже существует') ||
                lowerError.contains('already registered')) {
              errorMessage = 'Пользователь с таким email уже существует';
            } else if (lowerError.contains('invalid') || lowerError.contains('некорректный')) {
              errorMessage = 'Некорректный email';
            } else {
              errorMessage = 'Ошибка в email';
            }
          } else if (lowerError.contains('password')) {
            if (lowerError.contains('short') || lowerError.contains('короткий') || 
                lowerError.contains('length') || lowerError.contains('длина')) {
              errorMessage = 'Пароль должен быть не менее 6 символов';
            } else if (lowerError.contains('weak') || lowerError.contains('слабый')) {
              errorMessage = 'Пароль слишком слабый. Используйте буквы и цифры';
        } else {
              errorMessage = 'Ошибка в пароле';
            }
          }
        } else if (statusCode == 409) {
          errorMessage = 'Пользователь с таким email уже существует';
        } else if (statusCode == 404) {
          errorMessage = 'Сервер не найден. Проверьте настройки подключения.';
        } else if (statusCode == 500 || statusCode == 502 || statusCode == 503) {
          errorMessage = 'Ошибка сервера. Попробуйте позже.';
        }
        
        throw Exception(errorMessage);
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout ||
                 e.type == DioExceptionType.sendTimeout) {
        throw Exception('Превышено время ожидания. Проверьте подключение к интернету.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Сервер недоступен. Проверьте подключение к интернету.');
      } else {
        throw Exception('Ошибка подключения: ${e.message ?? "Неизвестная ошибка"}');
      }
    } catch (e) {
      print('[AuthRepository] signUp: Ошибка регистрации: $e');
      
      // Обрабатываем ошибки приведения типов и парсинга
      if (e.toString().contains('is not a subtype') || 
          e.toString().contains('type cast') ||
          e.toString().contains('TypeError')) {
        throw Exception('Ошибка обработки данных от сервера. Попробуйте позже.');
      }
      
      rethrow;
    }
  }

  /// Выход - удаляет токен из хранилища
  Future<void> signOut() async {
    try {
      print('[AuthRepository] signOut: Выход из аккаунта');
      
      await StorageService.delete(_tokenKey);
      await StorageService.delete(_userIdKey);
      await StorageService.delete(_userEmailKey);

      // Обновляем единый источник истины
      _ref.read(authStatusProvider.notifier).state = AuthStatus.unauthenticated;
      
      // Эмитим событие выхода в stream для обратной совместимости
      _authStateController.add(false);
      
      print('[AuthRepository] signOut: Токен удален');
    } catch (e) {
      print('[AuthRepository] signOut: Ошибка выхода: $e');
      rethrow;
    }
  }
  
  /// Получает текущего пользователя из хранилища
  Future<app_models.User?> currentUser() async {
    try {
      final userId = await StorageService.read(_userIdKey);
      final userEmail = await StorageService.read(_userEmailKey);
      
      if (userId == null || userEmail == null) {
        return null;
      }
      
      return app_models.User(
        id: userId,
        email: userEmail,
      );
    } catch (e) {
      print('[AuthRepository] currentUser: Ошибка получения пользователя: $e');
      return null;
    }
  }

  /// Получает токен из хранилища
  Future<String?> token() async {
    try {
      final token = await StorageService.read(_tokenKey);
      return token;
    } catch (e) {
      print('[AuthRepository] token: Ошибка получения токена: $e');
      return null;
    }
  }

  /// Стрим изменений состояния авторизации
  Stream<bool> authStateChanges() {
    // Сначала проверяем текущее состояние
    _checkAuthState();
    return _authStateController.stream;
  }

  /// Проверяет, есть ли валидный токен
  Future<bool> hasValidSession() async {
    final token = await this.token();
    return token != null && token.isNotEmpty;
  }

  void dispose() {
    _authStateController.close();
    }
  }
