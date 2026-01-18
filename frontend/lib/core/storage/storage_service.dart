import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Кроссплатформенный сервис для безопасного хранения данных.
/// На мобильных платформах использует FlutterSecureStorage.
/// На Web использует SharedPreferences (localStorage).
class StorageService {
  static FlutterSecureStorage? _secureStorage;
  static SharedPreferences? _prefs;
  
  /// Инициализирует хранилище (необязательно, но рекомендуется для Web)
  static Future<void> init() async {
    if (kIsWeb) {
      _prefs = await SharedPreferences.getInstance();
    } else {
      _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
        ),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock,
        ),
      );
    }
  }
  
  /// Запись значения
  static Future<void> write(String key, String value) async {
    if (kIsWeb) {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      final storage = _secureStorage ?? const FlutterSecureStorage();
      await storage.write(key: key, value: value);
    }
  }
  
  /// Чтение значения
  static Future<String?> read(String key) async {
    if (kIsWeb) {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      final storage = _secureStorage ?? const FlutterSecureStorage();
      return await storage.read(key: key);
    }
  }
  
  /// Удаление значения
  static Future<void> delete(String key) async {
    if (kIsWeb) {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      final storage = _secureStorage ?? const FlutterSecureStorage();
      await storage.delete(key: key);
    }
  }
  
  /// Очистка всех значений
  static Future<void> deleteAll() async {
    if (kIsWeb) {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      // Удаляем только ключи, связанные с авторизацией
      await prefs.remove('access_token');
      await prefs.remove('user_id');
      await prefs.remove('user_email');
    } else {
      final storage = _secureStorage ?? const FlutterSecureStorage();
      await storage.deleteAll();
    }
  }
  
  /// Проверяет, содержит ли хранилище ключ
  static Future<bool> containsKey(String key) async {
    if (kIsWeb) {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.containsKey(key);
    } else {
      final storage = _secureStorage ?? const FlutterSecureStorage();
      return await storage.containsKey(key: key);
    }
  }
}
