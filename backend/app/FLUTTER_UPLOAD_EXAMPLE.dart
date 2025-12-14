// Пример Flutter кода для загрузки фотографии ребенка
// Используйте этот код в вашем Flutter приложении

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'dart:convert';

class PhotoUploadService {
  final String baseUrl; // Например: "http://localhost:8000" или "https://your-api.com"
  final String? authToken; // Bearer token из Supabase Auth

  PhotoUploadService({
    required this.baseUrl,
    this.authToken,
  });

  /// Загрузить фотографию ребенка
  /// 
  /// [photoFile] - File объект с изображением
  /// 
  /// Возвращает публичный URL загруженной фотографии
  Future<String> uploadChildPhoto(File photoFile) async {
    try {
      // Проверяем, что файл существует
      if (!await photoFile.exists()) {
        throw Exception('Файл не существует: ${photoFile.path}');
      }

      // Создаем multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/children/photos'), // или '/upload'
      );

      // Добавляем авторизацию
      if (authToken != null) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }

      // Добавляем файл
      // Важно: поле должно называться 'file'
      var multipartFile = await http.MultipartFile.fromPath(
        'file', // Имя поля - обязательно 'file'
        photoFile.path,
        filename: path.basename(photoFile.path),
      );
      
      request.files.add(multipartFile);

      // Отправляем запрос
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      // Проверяем статус
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Парсим ответ
        var jsonResponse = json.decode(response.body);
        String photoUrl = jsonResponse['url'] as String;
        
        if (photoUrl.isEmpty) {
          throw Exception('Сервер вернул пустой URL фотографии');
        }
        
        return photoUrl;
      } else {
        // Обработка ошибок
        String errorMessage = 'Ошибка загрузки фотографии';
        try {
          var errorJson = json.decode(response.body);
          errorMessage = errorJson['detail'] ?? errorMessage;
        } catch (_) {
          errorMessage = 'HTTP ${response.statusCode}: ${response.body}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Ошибка при загрузке фотографии: $e');
    }
  }

  /// Загрузить фотографию и создать/обновить ребенка
  /// 
  /// [photoFile] - File объект с изображением
  /// [childData] - данные ребенка (без photo_url)
  /// 
  /// Возвращает child_id созданного/обновленного ребенка с photo_url
  Future<Map<String, dynamic>> uploadPhotoAndCreateChild({
    required File photoFile,
    required Map<String, dynamic> childData,
    String? childId, // Если указан, обновляем существующего ребенка
  }) async {
    try {
      // 1. Загружаем фотографию
      String photoUrl = await uploadChildPhoto(photoFile);
      
      // 2. Добавляем photo_url к данным ребенка
      childData['face_url'] = photoUrl;
      
      // 3. Создаем или обновляем ребенка
      if (childId != null) {
        // Обновляем существующего ребенка
        var updateRequest = http.Request(
          'PUT',
          Uri.parse('$baseUrl/children/$childId'),
        );
        
        if (authToken != null) {
          updateRequest.headers['Authorization'] = 'Bearer $authToken';
        }
        updateRequest.headers['Content-Type'] = 'application/json';
        updateRequest.body = json.encode(childData);
        
        var updateResponse = await updateRequest.send();
        var response = await http.Response.fromStream(updateResponse);
        
        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          throw Exception('Ошибка обновления ребенка: ${response.body}');
        }
      } else {
        // Создаем нового ребенка
        var createRequest = http.Request(
          'POST',
          Uri.parse('$baseUrl/children'),
        );
        
        if (authToken != null) {
          createRequest.headers['Authorization'] = 'Bearer $authToken';
        }
        createRequest.headers['Content-Type'] = 'application/json';
        createRequest.body = json.encode(childData);
        
        var createResponse = await createRequest.send();
        var response = await http.Response.fromStream(createResponse);
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          return json.decode(response.body);
        } else {
          throw Exception('Ошибка создания ребенка: ${response.body}');
        }
      }
    } catch (e) {
      throw Exception('Ошибка при загрузке фотографии и создании ребенка: $e');
    }
  }
}

// Пример использования:
/*
void main() async {
  // Инициализация сервиса
  final uploadService = PhotoUploadService(
    baseUrl: 'http://localhost:8000',
    authToken: 'your-supabase-auth-token',
  );

  // Выбираем файл (пример с image_picker)
  // File? pickedFile = await ImagePicker.pickImage(source: ImageSource.gallery);
  
  // Если используете реальный файл:
  File photoFile = File('/path/to/photo.jpg');

  try {
    // Вариант 1: Просто загрузить фотографию
    String photoUrl = await uploadService.uploadChildPhoto(photoFile);
    print('Фотография загружена: $photoUrl');

    // Вариант 2: Загрузить фотографию и сразу создать ребенка
    Map<String, dynamic> childData = {
      'name': 'Иван',
      'age': 5,
      'interests': 'роботы, космос, динозавры',
      'fears': 'темнота',
      'character': 'любознательный, активный',
      'moral': 'дружба важнее всего',
    };

    Map<String, dynamic> createdChild = await uploadService.uploadPhotoAndCreateChild(
      photoFile: photoFile,
      childData: childData,
    );
    
    print('Ребенок создан с фотографией: ${createdChild['child_id']}');
    
  } catch (e) {
    print('Ошибка: $e');
  }
}
*/

