import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as io;
import 'package:path/path.dart' as path;
import 'api_client.dart';
import '../models/child.dart';
import '../models/child_photo.dart';
import '../utils/image_compressor.dart';
import '../models/book.dart';
import '../models/scene.dart';
import '../models/task_status.dart';
import '../models/generate_full_book_response.dart';
import '../models/support_message.dart';
import '../models/support_message_reply.dart';

final backendApiProvider = Provider<BackendApi>((ref) {
  final dio = ref.watch(dioProvider);
  return BackendApi(dio);
});

/// Исключение для случая, когда задача не найдена (404)
class TaskNotFoundException implements Exception {
  final String taskId;
  
  TaskNotFoundException({required this.taskId});
  
  @override
  String toString() => 'Задача $taskId не найдена';
}

class BackendApi {
  final Dio _dio;

  BackendApi(this._dio);

  // Children
  /// Загружает фотографию на сервер без привязки к ребенку
  /// POST /upload
  /// Возвращает url из ответа: { "url": "http://..." }
  Future<String> uploadPhoto(io.File photoFile) async {
    try {
      print('[BackendApi] Uploading photo to server...');
      
      // Проверяем что файл существует
      if (!photoFile.existsSync()) {
        throw Exception('Файл не существует: ${photoFile.path}');
      }

      final fileSize = photoFile.lengthSync();
      if (fileSize == 0) {
        throw Exception('Файл пустой: ${photoFile.path}');
      }

      print('[BackendApi] uploadPhoto: Загрузка файла ${photoFile.path}, размер: $fileSize байт');

      // Используем basename для кроссплатформенной работы
      final filename = path.basename(photoFile.path);
      
      // Создаем MultipartFile
      final multipartFile = await MultipartFile.fromFile(
        photoFile.path,
        filename: filename,
      );

      print('[BackendApi] uploadPhoto: MultipartFile создан: filename=$filename, length=${multipartFile.length}');

      // FormData только с файлом
      final formData = FormData.fromMap({
        "file": multipartFile,
      });

      print('[BackendApi] uploadPhoto: Отправка POST запроса на /upload');
      final response = await _dio.post(
        '/upload',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      
      print('[BackendApi] uploadPhoto: Ответ получен, статус: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        
        if (data is Map<String, dynamic>) {
          // Читаем только "url" поле согласно формату ответа
          final photoUrl = data['url'] as String?;
          
          if (photoUrl == null || photoUrl.isEmpty) {
            print('[BackendApi] uploadPhoto: ОШИБКА - поле url отсутствует. Ответ сервера: $data');
            throw Exception('Сервер не вернул url загруженной фотографии. Ответ: $data');
          }
          
          print('[BackendApi] uploadPhoto: Фотография успешно загружена, url: $photoUrl');
          return photoUrl;
        }
        
        throw Exception('Некорректный формат ответа сервера. Ожидается Map с полем "url": $data');
      }
      
      throw Exception('Неожиданный статус ответа: ${response.statusCode}, данные: ${response.data}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.message ?? 
                          'Неизвестная ошибка';

      print('[BackendApi] uploadPhoto: DioException - статус: $statusCode, сообщение: $errorMessage');
      print('[BackendApi] uploadPhoto: Response data: ${e.response?.data}');

      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт заново.');
      }

      if (statusCode != null && statusCode >= 400) {
        throw Exception('Ошибка загрузки фотографии (${statusCode}): $errorMessage');
      }

      throw Exception('Ошибка сети при загрузке фотографии: ${e.message}');
    } catch (e) {
      print('[BackendApi] uploadPhoto: Неожиданная ошибка: $e');
      rethrow;
    }
  }

  /// Загружает фотографию на сервер с привязкой к ребенку
  /// POST /children/{child_id}/photos
  /// НЕ отправляет child_id в FormData, только в URL
  /// Возвращает face_url из ответа: { "child_id": "...", "face_url": "http://..." }
  Future<String> uploadChildPhoto(io.File photoFile, String childId) async {
    try {
      print('[BackendApi] ===== uploadChildPhoto START =====');
      print('[BackendApi] child_id: $childId');
      
      // Проверяем что файл существует
      if (!photoFile.existsSync()) {
        throw Exception('Файл не существует: ${photoFile.path}');
      }

      final fileSize = photoFile.lengthSync();
      if (fileSize == 0) {
        throw Exception('Файл пустой: ${photoFile.path}');
      }

      print('[BackendApi] uploadChildPhoto: Файл ${photoFile.path}, размер: $fileSize байт');

      // Используем basename для кроссплатформенной работы
      final filename = path.basename(photoFile.path);
      
      // Сжимаем фото перед загрузкой
      io.File fileToSend = photoFile;
      try {
        final compressed = await ImageCompressor.compress(photoFile);
        if (compressed != null && compressed.existsSync()) {
          fileToSend = compressed;
          print('[BackendApi] uploadChildPhoto: Используем сжатый файл ${fileToSend.path}, размер: ${fileToSend.lengthSync()} байт');
        } else {
          print('[BackendApi] uploadChildPhoto: Сжатие не удалось, отправляем оригинал');
        }
      } catch (e) {
        print('[BackendApi] uploadChildPhoto: Ошибка сжатия, отправляем оригинал: $e');
      }

      // Создаем MultipartFile
      final multipartFile = await MultipartFile.fromFile(
        fileToSend.path,
        filename: filename,
      );

      print('[BackendApi] uploadChildPhoto: MultipartFile создан: filename="$filename", length=${multipartFile.length}');

      // ВАЖНО: НЕ отправляем child_id в FormData, только в URL
      // FormData должен содержать ТОЛЬКО поле "file"
      final formData = FormData.fromMap({
        "file": multipartFile,
      });

      // Проверяем структуру FormData
      print('[BackendApi] uploadChildPhoto: FormData проверка:');
      print('[BackendApi]   - files.length: ${formData.files.length}');
      print('[BackendApi]   - fields.length: ${formData.fields.length}');
      print('[BackendApi]   - files: ${formData.files.map((e) => e.key).toList()}');
      print('[BackendApi]   - fields: ${formData.fields.map((e) => e.key).toList()}');
      
      // Убеждаемся, что child_id НЕ в FormData
      final hasChildIdInFormData = formData.fields.any((field) => field.key == 'child_id' || field.key == 'childId');
      if (hasChildIdInFormData) {
        print('[BackendApi] ОШИБКА: child_id найден в FormData! Это недопустимо!');
        throw Exception('child_id не должен быть в FormData, только в URL');
      }

      // Формируем endpoint - child_id ТОЛЬКО в URL
      final endpoint = '/children/$childId/photos';
      
      // Логируем полный URL для отладки
      final baseUrl = _dio.options.baseUrl;
      final fullUrl = '$baseUrl$endpoint';
      print('[BackendApi] uploadChildPhoto: Полный URL запроса: $fullUrl');
      print('[BackendApi] uploadChildPhoto: Base URL: $baseUrl');
      print('[BackendApi] uploadChildPhoto: Endpoint: $endpoint');
      
      final response = await _dio.post(
        endpoint,
        data: formData,
        options: Options(
          // НЕ устанавливаем contentType вручную - Dio установит его автоматически
          // для multipart/form-data с правильным boundary
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          followRedirects: false,
          validateStatus: (status) => status != null && status >= 200 && status < 300,
        ),
      );
      
      print('[BackendApi] uploadChildPhoto: Ответ получен');
      print('[BackendApi]   - Статус: ${response.statusCode}');
      print('[BackendApi]   - URL ответа: ${response.requestOptions.uri}');
      print('[BackendApi]   - Данные: ${response.data}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        
        if (data is Map<String, dynamic>) {
          // Читаем face_url из ответа согласно формату
          final faceUrl = data['face_url'] as String?;
          
          if (faceUrl == null || faceUrl.isEmpty) {
            print('[BackendApi] uploadChildPhoto: ОШИБКА - поле face_url отсутствует.');
            print('[BackendApi] uploadChildPhoto: Полный ответ сервера: $data');
            throw Exception('Сервер не вернул face_url загруженной фотографии. Ответ: $data');
          }
          
          print('[BackendApi] uploadChildPhoto: face_url получен: $faceUrl');
          print('[BackendApi] ===== uploadChildPhoto SUCCESS =====');
          return faceUrl;
        }
        
        print('[BackendApi] uploadChildPhoto: ОШИБКА - некорректный формат ответа');
        print('[BackendApi] uploadChildPhoto: Тип данных: ${data.runtimeType}');
        print('[BackendApi] uploadChildPhoto: Данные: $data');
        throw Exception('Некорректный формат ответа сервера. Ожидается Map с полем "face_url": $data');
      }
      
      print('[BackendApi] uploadChildPhoto: ОШИБКА - неожиданный статус');
      throw Exception('Неожиданный статус ответа: ${response.statusCode}, данные: ${response.data}');
    } on DioException catch (e) {
      print('[BackendApi] ===== uploadChildPhoto DioException =====');
      final statusCode = e.response?.statusCode;
      final requestUrl = e.requestOptions.uri.toString();
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.response?.data?.toString() ??
                          e.message ?? 
                          'Неизвестная ошибка';

      print('[BackendApi] uploadChildPhoto: DioException детали:');
      print('[BackendApi]   - Статус: $statusCode');
      print('[BackendApi]   - Тип ошибки: ${e.type}');
      print('[BackendApi]   - URL запроса: $requestUrl');
      print('[BackendApi]   - Сообщение: $errorMessage');
      print('[BackendApi]   - Response data: ${e.response?.data}');
      print('[BackendApi]   - Request data type: ${e.requestOptions.data.runtimeType}');

      if (statusCode == 401) {
        print('[BackendApi] uploadChildPhoto: 401 - Требуется авторизация');
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт заново.');
      }

      if (statusCode == 404) {
        print('[BackendApi] uploadChildPhoto: 404 - Endpoint не найден');
        print('[BackendApi] uploadChildPhoto: Проверьте, что backend имеет endpoint: POST $requestUrl');
        throw Exception('Endpoint не найден (404). Проверьте конфигурацию backend. Запрошенный URL: $requestUrl');
      }

      if (statusCode != null && statusCode >= 400) {
        throw Exception('Ошибка загрузки фотографии (${statusCode}): $errorMessage');
      }

      throw Exception('Ошибка сети при загрузке фотографии: ${e.message}');
    } catch (e) {
      print('[BackendApi] uploadChildPhoto: Неожиданная ошибка: $e');
      print('[BackendApi] uploadChildPhoto: Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Загружает несколько фотографий последовательно (общие фото без привязки к ребенку)
  /// Использует POST /upload
  Future<List<String>> uploadPhotos(List<io.File> photoFiles) async {
    final uploadedUrls = <String>[];
    
    print('[BackendApi] uploadPhotos: Начало загрузки ${photoFiles.length} фотографий на /upload');
    
    for (int i = 0; i < photoFiles.length; i++) {
      final photoFile = photoFiles[i];
      try {
        print('[BackendApi] uploadPhotos: Загрузка фотографии ${i + 1}/${photoFiles.length}');
        final url = await uploadPhoto(photoFile);
        uploadedUrls.add(url);
        print('[BackendApi] uploadPhotos: Фотография ${i + 1} успешно загружена, URL: $url');
      } catch (e) {
        // Выбрасываем ошибку вместо пропуска - чтобы пользователь знал о проблеме
        print('[BackendApi] uploadPhotos: ОШИБКА загрузки фотографии ${i + 1}: $e');
        throw Exception('Не удалось загрузить фотографию ${i + 1}: $e');
      }
    }
    
    print('[BackendApi] uploadPhotos: Все ${uploadedUrls.length} фотографий успешно загружены');
    return uploadedUrls;
  }

  /// Загружает несколько фотографий ребенка последовательно
  /// Использует POST /children/{childId}/photos через uploadChildPhoto
  Future<List<String>> uploadChildPhotos(List<io.File> photoFiles, String childId) async {
    final uploadedFaceUrls = <String>[];
    
    print('[BackendApi] uploadChildPhotos: Начало загрузки ${photoFiles.length} фотографий для ребенка $childId');
    
    for (int i = 0; i < photoFiles.length; i++) {
      final photoFile = photoFiles[i];
      try {
        print('[BackendApi] uploadChildPhotos: Загрузка фотографии ${i + 1}/${photoFiles.length}');
        final faceUrl = await uploadChildPhoto(photoFile, childId);
        uploadedFaceUrls.add(faceUrl);
        print('[BackendApi] uploadChildPhotos: Фотография ${i + 1} успешно загружена, face_url: $faceUrl');
      } catch (e) {
        // Выбрасываем ошибку вместо пропуска - чтобы пользователь знал о проблеме
        print('[BackendApi] uploadChildPhotos: ОШИБКА загрузки фотографии ${i + 1}: $e');
        throw Exception('Не удалось загрузить фотографию ${i + 1}: $e');
      }
    }
    
    print('[BackendApi] uploadChildPhotos: Все ${uploadedFaceUrls.length} фотографий успешно загружены');
    return uploadedFaceUrls;
  }

  Future<Child> createChild({
    required String name,
    required int age,
    required ChildGender gender,
    required String interests,
    required String fears,
    required String character,
    required String moral,
    String? faceUrl,
    List<io.File>? photos,
  }) async {
    try {
      print('[BackendApi] createChild: Создание ребенка');
      print('[BackendApi] createChild: Данные - name: $name, age: $age, gender: ${gender.toApiValue()}');
      
      // Подготавливаем данные для отправки
      final requestData = {
          'name': name,
          'age': age,
        'gender': gender.toApiValue(), // 'male' или 'female'
          'interests': interests,
          'fears': fears,
          'character': character,
          'moral': moral,
          if (faceUrl != null) 'face_url': faceUrl,
      };
      
      print('[BackendApi] createChild: Отправляемые данные: $requestData');
      
      // ШАГ 1: Сначала создаем ребенка БЕЗ фото
      final response = await _dio.post(
        '/children',
        data: requestData,
      );
      
      print('[BackendApi] createChild: Ответ получен, статус: ${response.statusCode}');
      print('[BackendApi] createChild: Данные ответа: ${response.data}');
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Не удалось создать ребёнка: статус ${response.statusCode}');
      }
      
      final responseData = response.data as Map<String, dynamic>;
      String childId;
      Child createdChild;
      
      // Получаем child_id из ответа (может быть int или String)
      if (responseData.containsKey('status') && responseData.containsKey('child_id')) {
        final childIdValue = responseData['child_id'];
        childId = childIdValue is int ? childIdValue.toString() : childIdValue as String;
        print('[BackendApi] createChild: Ребенок создан, child_id: $childId');
        
        // Получаем созданного ребёнка через GET или создаем временную модель
        final children = await getChildren();
        createdChild = children.firstWhere(
          (child) => child.id == childId,
          orElse: () => Child(
            id: childId,
            name: name,
            age: age,
            gender: gender,
            interests: interests,
            fears: fears,
            character: character,
            moral: moral,
            faceUrl: faceUrl,
          ),
        );
      } else if (responseData.containsKey('id')) {
        try {
          createdChild = Child.fromJson(responseData);
          childId = createdChild.id;
          print('[BackendApi] createChild: Ребенок создан из ответа, child_id: $childId');
        } catch (e) {
          print('[BackendApi] createChild: Ошибка парсинга ответа: $e');
          print('[BackendApi] createChild: Данные ответа: $responseData');
          // Пробуем извлечь id вручную
          final idValue = responseData['id'];
          childId = idValue is int ? idValue.toString() : idValue as String;
          createdChild = Child(
            id: childId,
            name: name,
            age: age,
            gender: gender,
            interests: interests,
            fears: fears,
            character: character,
            moral: moral,
            faceUrl: faceUrl,
          );
          print('[BackendApi] createChild: Ребенок создан вручную, child_id: $childId');
        }
      } else {
        throw Exception('Некорректный формат ответа от сервера');
      }
      
      // ШАГ 2: Если есть фото, загружаем их через /children/{child_id}/photos
      if (photos != null && photos.isNotEmpty) {
        print('[BackendApi] createChild: Начинаем загрузку ${photos.length} фотографий через /children/$childId/photos');
        
        try {
          // Загружаем первую фотографию (остальные можно загрузить позже если нужно)
          final faceUrlFromUpload = await uploadChildPhoto(photos.first, childId);
          
          // Обновляем faceUrl в модели
          createdChild = createdChild.copyWith(faceUrl: faceUrlFromUpload);
          
          print('[BackendApi] createChild: Фотография загружена, face_url сохранен: $faceUrlFromUpload');
          
          // Если нужно загрузить остальные фото, можно добавить цикл
          // for (int i = 1; i < photos.length; i++) {
          //   await uploadChildPhoto(photos[i], childId);
          // }
        } catch (e) {
          print('[BackendApi] createChild: ОШИБКА загрузки фотографии: $e');
          // Продолжаем, даже если фото не загрузилось
          // Ребенок уже создан, можно загрузить фото позже через updateChild
        }
      }
      
      print('[BackendApi] createChild: Ребенок успешно создан с faceUrl: ${createdChild.faceUrl}');
      return createdChild;
      
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.message ?? 
                          'Неизвестная ошибка';
      
      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт заново.');
      }
      
      if (statusCode != null && statusCode >= 400) {
        throw Exception('Ошибка сервера: $errorMessage');
      }
      
      rethrow;
    }
  }

  Future<List<Child>> getChildren() async {
    try {
      final response = await _dio.get('/children');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as List;
        return data.map((json) {
          try {
            // Логируем данные для отладки
            final jsonMap = json as Map<String, dynamic>;
            if (!jsonMap.containsKey('gender')) {
              print('[BackendApi] getChildren: ВНИМАНИЕ - поле gender отсутствует в данных: $jsonMap');
              print('[BackendApi] getChildren: Будет использовано дефолтное значение: female');
            }
            return Child.fromJson(jsonMap);
          } catch (e) {
            print('[BackendApi] getChildren: Ошибка парсинга ребенка: $e');
            print('[BackendApi] getChildren: Данные: $json');
            rethrow;
          }
        }).toList();
      }
      return [];
    } on DioException catch (e) {
      // 404 или 401 - возвращаем пустой список (неавторизован или нет данных)
      if (e.response?.statusCode == 404 || e.response?.statusCode == 401) {
        print('[BackendApi] getChildren: Endpoint не найден или требуется авторизация');
        return [];
      }
      rethrow;
    } catch (e) {
      print('[BackendApi] getChildren: Неожиданная ошибка: $e');
      print('[BackendApi] getChildren: Тип ошибки: ${e.runtimeType}');
      return [];
    }
  }

  Future<Child> updateChild({
    required String id,
    String? name,
    int? age,
    ChildGender? gender,
    String? interests,
    String? fears,
    String? character,
    String? moral,
    String? faceUrl,
    List<io.File>? photos,
    List<String>? existingPhotoUrls,
  }) async {
    try {
      print('[BackendApi] updateChild: Обновление ребенка $id');
      
      // Определяем финальный faceUrl (используем существующий или переданный)
      String? finalFaceUrl = faceUrl;
      if (existingPhotoUrls != null && existingPhotoUrls.isNotEmpty && finalFaceUrl == null) {
        finalFaceUrl = existingPhotoUrls.first;
      }

      // ШАГ 1: Обновляем данные ребенка
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (age != null) data['age'] = age;
      if (gender != null) data['gender'] = gender.toApiValue();
      if (interests != null) data['interests'] = interests;
      if (fears != null) data['fears'] = fears;
      if (character != null) data['character'] = character;
      if (moral != null) data['moral'] = moral;
      if (finalFaceUrl != null) data['face_url'] = finalFaceUrl;

      final response = await _dio.put(
        '/children/$id',
        data: data,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Не удалось обновить ребёнка: статус ${response.statusCode}');
      }

      Child updatedChild;
      try {
        updatedChild = Child.fromJson(response.data as Map<String, dynamic>);
        print('[BackendApi] updateChild: Данные ребенка обновлены');
      } catch (e) {
        print('[BackendApi] updateChild: Ошибка парсинга ответа: $e');
        print('[BackendApi] updateChild: Данные ответа: ${response.data}');
        rethrow;
      }
      
      // ШАГ 2: Если есть новые фото, загружаем их через /children/{id}/photos
      if (photos != null && photos.isNotEmpty) {
        print('[BackendApi] updateChild: ✅ Начинаем загрузку ${photos.length} фотографий через /children/$id/photos');
        print('[BackendApi] updateChild: Список файлов: ${photos.map((p) => p.path).join(", ")}');
        
        String? lastUploadedFaceUrl;
        int uploadedCount = 0;
        int failedCount = 0;
        
        // Загружаем КАЖДОЕ выбранное фото, чтобы в профиле было до 5 фотографий
        for (int i = 0; i < photos.length; i++) {
          final photo = photos[i];
          try {
            print('[BackendApi] updateChild: 📤 Загрузка фото ${i + 1}/${photos.length}: ${photo.path}');
            
          // ВАЖНО: uploadChildPhoto отправляет POST /children/{id}/photos
          // child_id передается ТОЛЬКО в URL, НЕ в FormData
            final faceUrlFromUpload = await uploadChildPhoto(photo, id);
            lastUploadedFaceUrl = faceUrlFromUpload;
            uploadedCount++;
            
            print('[BackendApi] updateChild: ✅ Фото ${i + 1}/${photos.length} успешно загружено: $faceUrlFromUpload');
          } catch (e) {
            failedCount++;
            print('[BackendApi] updateChild: ❌ ОШИБКА загрузки фото ${i + 1}/${photos.length}: $e');
            // Продолжаем загрузку остальных фото, даже если одно не загрузилось
          }
        }
        
        print('[BackendApi] updateChild: 📊 ИТОГО: Загружено $uploadedCount из ${photos.length} фотографий (ошибок: $failedCount)');
          
        // Обновляем faceUrl в модели через copyWith (используем последнее успешно загруженное фото)
        if (lastUploadedFaceUrl != null) {
          final childWithPhoto = updatedChild.copyWith(faceUrl: lastUploadedFaceUrl);
          print('[BackendApi] updateChild: face_url обновлен: $lastUploadedFaceUrl');
          return childWithPhoto;
        } else {
          print('[BackendApi] updateChild: ⚠️ Не удалось загрузить ни одно фото, возвращаем ребенка без обновления face_url');
        }
      }
      
      print('[BackendApi] updateChild: Ребенок успешно обновлен с faceUrl: ${updatedChild.faceUrl}');
      return updatedChild;
      
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.message ?? 
                          'Неизвестная ошибка';

      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт заново.');
      }

      if (statusCode != null && statusCode >= 400) {
        throw Exception('Ошибка сервера: $errorMessage');
      }

      rethrow;
    }
  }

  Future<void> deleteChild(String id) async {
    try {
      print('[BackendApi] deleteChild: Удаление ребенка $id');
      
      final response = await _dio.delete('/children/$id');

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('[BackendApi] deleteChild: Ребенок успешно удален');
        return;
      }
      
      throw Exception('Не удалось удалить ребёнка: статус ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.message ?? 
                          'Неизвестная ошибка';

      print('[BackendApi] deleteChild: Ошибка удаления - статус: $statusCode, сообщение: $errorMessage');
      
      // Проверка на DNS ошибку в сообщении
      if (errorMessage.contains('Name or service not known') || 
          errorMessage.contains('DNS') ||
          errorMessage.contains('проверке существования ребёнка')) {
        throw Exception('Ошибка подключения к серверу. Пожалуйста, попробуйте позже.');
      }

      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт заново.');
      }

      if (statusCode == 404) {
        throw Exception('Ребёнок не найден');
      }

      if (statusCode == 403) {
        throw Exception('Нет прав на удаление этого ребёнка');
      }

      if (statusCode != null && statusCode >= 500) {
        throw Exception('Сервер временно недоступен. Мы уже чиним магию! Попробуйте через минуту.');
      }

      if (statusCode != null && statusCode >= 400) {
        throw Exception('Ошибка сервера: $errorMessage');
      }

      rethrow;
    } catch (e) {
      print('[BackendApi] deleteChild: Неожиданная ошибка: $e');
      rethrow;
    }
  }

  /// Получает все фотографии ребенка
  /// GET /children/{child_id}/photos
  /// 
  /// Параметры:
  /// - childId: ID ребенка
  /// 
  /// Возвращает ChildPhotosResponse с массивом фотографий (до 5)
  Future<ChildPhotosResponse> getChildPhotos(String childId) async {
    try {
      print('[BackendApi] getChildPhotos: Загрузка фотографий для ребенка $childId');
      
      final response = await _dio.get('/children/$childId/photos');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final photosResponse = ChildPhotosResponse.fromJson(data);
        
        print('[BackendApi] getChildPhotos: Загружено ${photosResponse.photos.length} фотографий');
        
        return photosResponse;
      }
      
      // Если ответ пустой или неожиданный формат, возвращаем пустой список
      print('[BackendApi] getChildPhotos: Неожиданный формат ответа, возвращаем пустой список');
      return ChildPhotosResponse(
        childId: childId,
        photos: [],
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      
      // 404 - ребенок не найден или нет фотографий
      if (statusCode == 404) {
        print('[BackendApi] getChildPhotos: Ребенок не найден или нет фотографий (404)');
        return ChildPhotosResponse(
          childId: childId,
          photos: [],
        );
      }
      
      // 405 - метод не поддерживается (бэкенд не реализовал GET для этого эндпоинта)
      if (statusCode == 405) {
        print('[BackendApi] getChildPhotos: Метод GET не поддерживается (405). Возвращаем пустой список.');
        return ChildPhotosResponse(
          childId: childId,
          photos: [],
        );
      }
      
      // 401 - требуется авторизация
      if (statusCode == 401) {
        print('[BackendApi] getChildPhotos: Требуется авторизация (401)');
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт заново.');
      }
      
      print('[BackendApi] getChildPhotos: Ошибка загрузки фотографий - статус: $statusCode');
      rethrow;
    } catch (e) {
      print('[BackendApi] getChildPhotos: Неожиданная ошибка: $e');
      rethrow;
    }
  }

  /// Удаляет фотографию ребенка
  /// DELETE /children/{child_id}/photos
  /// 
  /// Параметры:
  /// - childId: ID ребенка
  /// - photoUrl: URL фотографии для удаления
  /// 
  /// Возвращает void при успешном удалении
  Future<void> deleteChildPhoto({
    required String childId,
    required String photoUrl,
  }) async {
    try {
      print('[BackendApi] deleteChildPhoto: Удаление фото для ребенка $childId');
      print('[BackendApi] deleteChildPhoto: URL фото: $photoUrl');
      
      final response = await _dio.delete(
        '/children/$childId/photos',
        data: {
          'photo_url': photoUrl,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('[BackendApi] deleteChildPhoto: Фото успешно удалено');
        return;
      }
      
      throw Exception('Не удалось удалить фото: статус ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.message ?? 
                          'Неизвестная ошибка';

      print('[BackendApi] deleteChildPhoto: Ошибка удаления - статус: $statusCode, сообщение: $errorMessage');

      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт заново.');
      }

      if (statusCode == 404) {
        throw Exception('Фото не найдено');
      }

      if (statusCode == 403) {
        throw Exception('Нет прав на удаление этого фото');
      }

      if (statusCode != null && statusCode >= 500) {
        throw Exception('Сервер временно недоступен. Попробуйте позже.');
      }

      if (statusCode != null && statusCode >= 400) {
        throw Exception('Ошибка сервера: $errorMessage');
      }

      rethrow;
    } catch (e) {
      print('[BackendApi] deleteChildPhoto: Неожиданная ошибка: $e');
      rethrow;
    }
  }

  /// Устанавливает главное фото (avatar) для ребенка
  /// PUT /children/{child_id}/photos/avatar
  /// 
  /// Параметры:
  /// - childId: ID ребенка
  /// - photoUrl: URL фотографии, которую нужно сделать главной
  /// 
  /// Возвращает void, так как после успешного ответа нужно инвалидировать провайдеры
  Future<void> setChildAvatar({
    required String childId,
    required String photoUrl,
  }) async {
    try {
      print('[BackendApi] setChildAvatar: Установка avatar для ребенка $childId');
      print('[BackendApi] setChildAvatar: URL фото: $photoUrl');
      
      final response = await _dio.put(
        '/children/$childId/photos/avatar',
        data: {
          'photo_url': photoUrl,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[ChildAvatar] set avatar success: $photoUrl');
        print('[BackendApi] setChildAvatar: Avatar успешно установлен');
        
        // Не пытаемся парсить ответ, так как API может не возвращать полный Child
        // Вместо этого инвалидируем провайдеры в UI
        return;
      }
      
      throw Exception('Не удалось установить avatar: статус ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.message ?? 
                          'Неизвестная ошибка';

      print('[BackendApi] setChildAvatar: Ошибка установки avatar - статус: $statusCode, сообщение: $errorMessage');

      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт заново.');
      }

      if (statusCode == 404) {
        throw Exception('Ребёнок или фото не найдены');
      }

      if (statusCode == 403) {
        throw Exception('Нет прав на изменение этого ребёнка');
      }

      if (statusCode != null && statusCode >= 500) {
        throw Exception('Сервер временно недоступен. Попробуйте позже.');
      }

      if (statusCode != null && statusCode >= 400) {
        throw Exception('Ошибка сервера: $errorMessage');
      }

      rethrow;
    } catch (e) {
      print('[BackendApi] setChildAvatar: Неожиданная ошибка: $e');
      rethrow;
    }
  }

  // Books
  Future<List<Book>> getBooks() async {
    const maxRetries = 2;
    const retryDelay = Duration(milliseconds: 400);

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      final isLastAttempt = attempt == maxRetries;
      try {
        final response = await _dio.get('/books');
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          if (data is List) {
            return data
                .map((json) => Book.fromJson(json as Map<String, dynamic>))
                .toList();
          } else {
            print('[BackendApi] getBooks: Некорректный формат ответа, ожидается List. Ответ: $data');
            // Возвращаем пустой список, но пусть UI покажет предупреждение
            return [];
          }
        }

        // Неуспешный статус
        final status = response.statusCode ?? -1;
        print('[BackendApi] getBooks: Статус $status, попытка ${attempt + 1}/$maxRetries');

        if (status >= 500 && !isLastAttempt) {
          await Future.delayed(retryDelay);
          continue;
        }

        if (status >= 500) {
          throw Exception('Сервер временно недоступен, попробуйте позже.');
        }

        // 4xx — возвращаем пустой список
        return [];
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode;
        final shouldRetry = statusCode != null && statusCode >= 500;

        print('[BackendApi] getBooks: DioException ${e.type}, статус: $statusCode, попытка ${attempt + 1}/$maxRetries');

        if (shouldRetry && !isLastAttempt) {
          await Future.delayed(retryDelay);
          continue;
        }

        if (statusCode == 401) {
          throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт заново.');
        }

        if (statusCode == 402) {
          throw Exception('Недостаточно средств на DeepSeek, попробуйте позже.');
        }

        if (statusCode != null && statusCode >= 500) {
          throw Exception('Сервер временно недоступен, попробуйте позже.');
        }

        // Остальные ошибки — возвращаем пустой список, чтобы UI показал пусто без падения
        return [];
      } catch (e) {
        print('[BackendApi] getBooks: Неожиданная ошибка: $e');
        if (isLastAttempt) {
          throw Exception('Не удалось загрузить список книг. Попробуйте позже.');
        }
      }
    }

    // Fallback — не должен достигаться
    return [];
  }

  Future<List<Scene>> getBookScenes(String bookId) async {
    try {
      print('[BackendApi] getBookScenes: Запрос сцен для книги $bookId');
      final response = await _dio.get('/books/$bookId/scenes');
      print('[BackendApi] getBookScenes: Статус ответа: ${response.statusCode}');
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        print('[BackendApi] getBookScenes: Тип данных: ${data.runtimeType}');
        List<dynamic> scenesList;
        
        // Handle both response shapes: List OR {scenes: List}
        if (data is List) {
          scenesList = data;
          print('[BackendApi] getBookScenes: Данные - это List, количество элементов: ${scenesList.length}');
        } else if (data is Map<String, dynamic> && data.containsKey('scenes')) {
          final scenesValue = data['scenes'];
          if (scenesValue is List) {
            scenesList = scenesValue;
            print('[BackendApi] getBookScenes: Данные - это Map с scenes, количество элементов: ${scenesList.length}');
          } else {
            print('[BackendApi] getBookScenes: ОШИБКА - поле scenes не является List. Тип: ${scenesValue.runtimeType}, Значение: $scenesValue');
            return [];
          }
        } else {
          print('[BackendApi] getBookScenes: ОШИБКА - неожиданный формат ответа. Тип: ${data.runtimeType}, Значение: $data');
          return [];
        }
        
        if (scenesList.isEmpty) {
          print('[BackendApi] getBookScenes: ⚠️ Список сцен пуст для книги $bookId');
          return [];
        }
        
        print('[BackendApi] getBookScenes: Начинаем парсинг ${scenesList.length} сцен');
        final parsedScenes = scenesList
            .map((json) {
              try {
                // Безопасный парсинг с обработкой null значений
                final sceneData = json as Map<String, dynamic>;
                // Преобразуем все потенциально null поля в безопасные строки
                // ВАЖНО: Бэкенд возвращает image_url (не final_url), draft_url (не draft_image_url)
                // Безопасное преобразование order в int (может быть int, String или null)
                int orderValue = 0;
                final orderData = sceneData['order'];
                if (orderData != null) {
                  if (orderData is int) {
                    orderValue = orderData;
                  } else if (orderData is num) {
                    orderValue = orderData.toInt();
                  } else if (orderData is String) {
                    orderValue = int.tryParse(orderData) ?? 0;
                  }
                }
                
                final safeData = <String, dynamic>{
                  'id': sceneData['id']?.toString() ?? '',
                  'book_id': sceneData['book_id']?.toString() ?? '',
                  'order': orderValue,
                  'short_summary': sceneData['short_summary']?.toString() ?? '',
                  'image_prompt': sceneData['image_prompt']?.toString(),
                  'draft_url': sceneData['draft_url']?.toString() ?? sceneData['draft_image_url']?.toString(), // Поддержка старого и нового формата
                  'image_url': sceneData['image_url']?.toString() ?? sceneData['final_url']?.toString() ?? sceneData['final_image_url']?.toString(), // Поддержка всех вариантов
                };
                final scene = Scene.fromJson(safeData);
                print('[BackendApi] getBookScenes: ✅ Сцена распарсена: order=${scene.order}, id=${scene.id}');
                return scene;
              } catch (e) {
                print('[BackendApi] getBookScenes: ❌ Ошибка парсинга сцены: $e');
                print('[BackendApi] getBookScenes: Данные сцены: $json');
                // Возвращаем пустую сцену вместо rethrow, чтобы не ломать весь список
                return Scene(
                  id: json['id']?.toString() ?? '0',
                  bookId: json['book_id']?.toString() ?? '',
                  order: (json['order'] as num?)?.toInt() ?? 0,
                  shortSummary: json['short_summary']?.toString() ?? '',
                  imagePrompt: json['image_prompt']?.toString(),
                  draftUrl: json['draft_url']?.toString() ?? json['draft_image_url']?.toString(), // Поддержка старого и нового формата
                  finalUrl: json['image_url']?.toString() ?? json['final_url']?.toString() ?? json['final_image_url']?.toString(), // Поддержка всех вариантов
                );
              }
            })
            .where((scene) {
              final isValid = scene.id.isNotEmpty && scene.bookId.isNotEmpty;
              if (!isValid) {
                print('[BackendApi] getBookScenes: ⚠️ Сцена отфильтрована (пустой id или book_id): id=${scene.id}, bookId=${scene.bookId}');
              }
              return isValid;
            })
            .toList();
        
        print('[BackendApi] getBookScenes: ✅ Успешно распарсено ${parsedScenes.length} сцен из ${scenesList.length}');
        return parsedScenes;
      }
      print('[BackendApi] getBookScenes: ⚠️ Пустой ответ или статус не 200');
      return [];
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      print('[BackendApi] getBookScenes: DioException, статус: $statusCode');
      if (statusCode == 404 || statusCode == 401) {
        print('[BackendApi] getBookScenes: Endpoint не найден или требуется авторизация');
        return [];
      }
      print('[BackendApi] getBookScenes: Неожиданная DioException: ${e.message}');
      rethrow;
    } catch (e) {
      print('[BackendApi] getBookScenes: ❌ Неожиданная ошибка: $e');
      print('[BackendApi] getBookScenes: Тип ошибки: ${e.runtimeType}');
      return [];
    }
  }

  /// DELETE /books/:bookId
  /// Удаляет книгу по ID
  /// 
  /// Возвращает void при успешном удалении
  /// Выбрасывает Exception при ошибке
  Future<void> deleteBook(String bookId) async {
    try {
      print('[BackendApi] deleteBook: Удаление книги $bookId');
      
      final response = await _dio.delete('/books/$bookId');
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        print('[BackendApi] deleteBook: Книга успешно удалена');
        return;
      }
      
      throw Exception('Не удалось удалить книгу: статус ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.message ?? 
                          'Неизвестная ошибка';
      
      print('[BackendApi] deleteBook: Ошибка удаления - статус: $statusCode, сообщение: $errorMessage');
      
      if (statusCode == 404) {
        throw Exception('Книга не найдена');
      }
      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт заново.');
      }
      if (statusCode == 403) {
        throw Exception('Нет прав на удаление этой книги');
      }
      if (statusCode == 405) {
        throw Exception('Удаление книги не поддерживается на сервере. Обратитесь в поддержку.');
      }
      
      throw Exception('Ошибка удаления книги: $errorMessage');
    } catch (e) {
      print('[BackendApi] deleteBook: Неожиданная ошибка: $e');
      rethrow;
    }
  }

  /// POST /books/generate_full_book
  /// Генерирует полную книгу для указанного ребенка с указанным стилем
  /// 
  /// Параметры:
  /// - childId: ID ребенка
  /// - style: стиль иллюстраций (storybook, cartoon, pixar, disney, watercolor)
  /// - numPages: количество страниц (по умолчанию 20, без учета обложки)
  /// 
  /// Возвращает:
  /// {
  ///   "task_id": "03cbf305-4a8a-4a94-bbb0-5a08312ad567",
  ///   "message": "Книга генерируется",
  ///   "child_id": "e2e160ad-63d9-4007-84fe-e41be8e6cde0"
  /// }
  Future<GenerateFullBookResponse> generateFullBook({
    required String childId,
    required String style,
    int numPages = 20, // Количество страниц без учета обложки
    required String theme, // Описание темы книги (обязательное поле согласно API)
  }) async {
    try {
      print('[BackendApi] [API REQUEST] POST /books/generate_full_book');
      print('[BackendApi] Request data: {child_id: $childId, style: $style, num_pages: $numPages, theme: $theme}');
      
      final response = await _dio.post(
        '/books/generate_full_book',
        data: {
          'child_id': childId,
          'style': style,
          'num_pages': numPages, // 10 или 20 страниц без учета обложки
          'theme': theme, // Описание темы книги (обязательное поле)
        },
      );
      
      print('[BackendApi] [API RESPONSE] Status: ${response.statusCode}');
      print('[BackendApi] [API RESPONSE] Data: ${response.data}');
      
      // Проверяем статус
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Ошибка генерации книги: statusCode=${response.statusCode}',
        );
      }

      // Проверяем формат ответа
      if (response.data is! Map<String, dynamic>) {
        throw const FormatException(
          'Некорректный ответ от сервера: ожидается JSON-объект',
        );
      }

      final data = response.data as Map<String, dynamic>;
      
      // Парсим ответ через модель
      return GenerateFullBookResponse.fromJson(data);
    } on DioException catch (e, stackTrace) {
      print('[BackendApi] ❌ [API ERROR] DioException при генерации книги:');
      print('[BackendApi] Тип: ${e.type}');
      print('[BackendApi] Сообщение: ${e.message}');
      print('[BackendApi] Status Code: ${e.response?.statusCode}');
      print('[BackendApi] Response Data: ${e.response?.data}');
      print('[BackendApi] Request Path: ${e.requestOptions.path}');
      print('[BackendApi] Request Data: ${e.requestOptions.data}');
      print('[BackendApi] Stack Trace: $stackTrace');
      
      if (e.response?.statusCode == 404) {
        throw Exception('Endpoint /books/generate_full_book не найден на сервере. Возможно, функционал генерации книг еще не реализован на backend или требуется другой путь. Проверьте подключение к серверу или обратитесь к администратору.');
      }
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт заново.');
      }
      if (e.response?.statusCode == 500) {
        throw Exception('Ошибка сервера (500). Попробуйте позже или обратитесь в поддержку.');
      }
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Превышено время ожидания. Проверьте подключение к интернету.');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw Exception('Ошибка подключения к серверу. Проверьте интернет-соединение.');
      }
      rethrow;
    } on FormatException catch (e, stackTrace) {
      print('[BackendApi] ❌ [API ERROR] FormatException при генерации книги:');
      print('[BackendApi] Сообщение: ${e.message}');
      print('[BackendApi] Source: ${e.source}');
      print('[BackendApi] Offset: ${e.offset}');
      print('[BackendApi] Stack Trace: $stackTrace');
      rethrow;
    } catch (e, stackTrace) {
      print('[BackendApi] ❌ [API ERROR] Неожиданная ошибка при генерации книги:');
      print('[BackendApi] Тип: ${e.runtimeType}');
      print('[BackendApi] Сообщение: $e');
      print('[BackendApi] Stack Trace: $stackTrace');
      if (e.toString().contains('type') && e.toString().contains('Null')) {
        throw Exception('Ошибка парсинга ответа от сервера: некорректный формат данных');
      }
      rethrow;
    }
  }

  Future<TaskStatus> checkTaskStatus(String taskId) async {
    try {
      print('[BackendApi] [API REQUEST] GET /books/task_status/$taskId');
      final response = await _dio.get('/books/task_status/$taskId');
      print('[BackendApi] [API RESPONSE] Status: ${response.statusCode}');
      print('[BackendApi] [API RESPONSE] Data: ${response.data}');
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        
        // Безопасная проверка типа
        if (data is! Map<String, dynamic>) {
          throw Exception('Некорректный формат ответа от сервера: ожидается JSON-объект');
        }
        
        // Если в ответе нет поля 'id', добавляем его из taskId (из URL)
        final dataWithId = Map<String, dynamic>.from(data);
        if (dataWithId['id'] == null) {
          dataWithId['id'] = taskId;
        }
        
        // Проверяем наличие обязательного поля status
        if (dataWithId['status'] == null) {
          throw Exception('Некорректный ответ от сервера: отсутствует обязательное поле status');
        }
        
        // Безопасный парсинг - поля могут отсутствовать, но не должны быть null для обязательных
        try {
          return TaskStatus.fromJson(dataWithId);
        } catch (e) {
          throw Exception('Ошибка парсинга ответа от сервера: $e');
        }
      }
      throw Exception('Не удалось получить статус задачи: статус ${response.statusCode}');
    } on DioException catch (e) {
      print('[BackendApi] [API ERROR] DioException: ${e.message}');
      print('[BackendApi] [API ERROR] URL: ${e.requestOptions.uri}');
      print('[BackendApi] [API ERROR] Status: ${e.response?.statusCode}');
      
      // Обработка 502 Bad Gateway - сервер временно недоступен
      if (e.response?.statusCode == 502) {
        print('[BackendApi] Bad Gateway (502) - сервер временно недоступен. Задача может быть потеряна при перезапуске сервера.');
        // При 502 также считаем задачу потерянной, так как сервер был перезапущен
        throw TaskNotFoundException(taskId: taskId);
      }
      
      if (e.response?.statusCode == 404) {
        // При 404 пробуем создать TaskStatus со статусом 'lost'
        // Это позволит UI обработать ситуацию и предложить продолжить генерацию
        print('[BackendApi] Task not found (404), creating lost status for taskId: $taskId');
        throw TaskNotFoundException(taskId: taskId);
      }
      if (e.response?.statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт заново.');
      }
      rethrow;
    } catch (e) {
      if (e is TaskNotFoundException) rethrow;
      if (e.toString().contains('type') && e.toString().contains('Null')) {
        throw Exception('Ошибка парсинга ответа от сервера: некорректный формат данных');
      }
      rethrow;
    }
  }
  
  /// Продолжить генерацию финальных изображений для книги
  /// POST /api/v1/generate_final_images
  Future<GenerateFullBookResponse> continueFinalImagesGeneration({
    required String bookId,
    required String faceUrl,
    required String style,
  }) async {
    try {
      print('[BackendApi] [API REQUEST] POST /generate_final_images');
      print('[BackendApi] Request data: {book_id: $bookId, face_url: $faceUrl, style: $style}');
      
      final response = await _dio.post(
        '/generate_final_images',
        data: {
          'book_id': bookId,
          'face_url': faceUrl,
          'style': style,
        },
      );
      
      print('[BackendApi] [API RESPONSE] Status: ${response.statusCode}');
      print('[BackendApi] [API RESPONSE] Data: ${response.data}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return GenerateFullBookResponse.fromJson(data);
      }
      throw Exception('Не удалось продолжить генерацию: статус ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 404) {
        throw Exception('Книга не найдена. Проверьте правильность book_id.');
      }
      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт.');
      }
      if (statusCode == 400) {
        final errorMessage = e.response?.data?['detail']?.toString() ?? 
                           e.response?.data?['message']?.toString() ?? 
                           'Некорректный запрос';
        throw Exception(errorMessage);
      }
      rethrow;
    }
  }

  Future<Scene> regenerateScene({
    required String bookId,
    required int sceneOrder,
    String? instruction,
  }) async {
    try {
      final response = await _dio.post(
        '/books/$bookId/regenerate_scene',
        data: {
          'scene_index': sceneOrder,
          if (instruction != null) 'instruction': instruction,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Scene.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Не удалось перегенерировать сцену: статус ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Сцена не найдена. Проверьте правильность параметров.');
      }
      if (e.response?.statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт.');
      }
      rethrow;
    }
  }

  Future<void> selectStyle({
    required String bookId,
    required String style,
    required String mode,
  }) async {
    try {
      final response = await _dio.post(
        '/select_style',
        data: {
          'book_id': bookId,
          'final_style': style,
          'mode': mode,
        },
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Не удалось выбрать стиль: статус ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Для создания ребёнка необходимо войти в аккаунт. Пожалуйста, авторизуйтесь.');
      }
      if (e.response?.statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт.');
      }
      rethrow;
    }
  }

  // Book Workflow Methods
  /// Генерирует черновик книги
  /// POST /books/generate_draft
  Future<Book> generateDraft({
    required String childId,
    required String style,
  }) async {
    try {
      final response = await _dio.post(
        '/books/generate_draft',
        data: {
          'child_id': childId,
          'style': style,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Book.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Не удалось создать черновик: статус ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.message ?? 
                          'Неизвестная ошибка';
      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт.');
      }
      if (statusCode != null && statusCode >= 400) {
        throw Exception('Ошибка создания черновика: $errorMessage');
      }
      rethrow;
    }
  }

  /// Обновляет текст конкретной сцены
  /// POST /books/{book_id}/scenes/{scene_index}/update_text
  Future<Scene> updateText({
    required String bookId,
    required int sceneIndex,
    required String instruction,
  }) async {
    try {
      print('[BackendApi] updateText: Обновление текста сцены $sceneIndex книги $bookId');
      print('[BackendApi] updateText: Инструкция: $instruction');
      
      final response = await _dio.post(
        '/books/$bookId/scenes/$sceneIndex/update_text',
        data: {
          'text_instructions': instruction,
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data as Map<String, dynamic>;
        // Бэкенд возвращает обновлённую сцену
        print('[BackendApi] updateText: Текст успешно обновлён');
        return Scene.fromJson(responseData);
      }
      throw Exception('Не удалось обновить текст: статус ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.message ?? 
                          'Неизвестная ошибка';
      print('[BackendApi] updateText: Ошибка - статус: $statusCode, сообщение: $errorMessage');
      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт.');
      }
      if (statusCode == 404) {
        throw Exception('Книга или сцена не найдена.');
      }
      if (statusCode != null && statusCode >= 400) {
        throw Exception('Ошибка обновления текста: $errorMessage');
      }
      rethrow;
    }
  }

  /// Отправить книгу на финальную генерацию с учетом изменений пользователя
  /// POST /books/{book_id}/generate_final_version
  /// 
  /// Этот метод отправляет черновик книги на генерацию финальной версии.
  /// Бэкенд должен:
  /// 1. Учесть все изменения пользователя (текст, изображения)
  /// 2. Сгенерировать финальные изображения для всех сцен
  /// 3. Вернуть task_id для отслеживания прогресса
  /// 
  /// После завершения генерации статус книги должен измениться на 'editing',
  /// и пользователь сможет финализировать книгу.
  Future<GenerateFullBookResponse> generateFinalVersion(String bookId) async {
    try {
      print('[BackendApi] [API REQUEST] POST /books/$bookId/generate_final_version');
      
      final response = await _dio.post(
        '/books/$bookId/generate_final_version',
      );
      
      print('[BackendApi] [API RESPONSE] Status: ${response.statusCode}');
      print('[BackendApi] [API RESPONSE] Data: ${response.data}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return GenerateFullBookResponse.fromJson(data);
      }
      throw Exception('Не удалось отправить на финальную генерацию: статус ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.message ?? 
                          'Неизвестная ошибка';
      
      print('[BackendApi] Generate final version error: ${e.message}');
      
      if (statusCode == 404) {
        throw Exception('Книга не найдена');
      }
      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт.');
      }
      if (statusCode == 400) {
        throw Exception('Некорректный запрос: $errorMessage');
      }
      if (statusCode == 422) {
        throw Exception('Книга не может быть отправлена на генерацию: $errorMessage');
      }
      throw Exception('Ошибка отправки на генерацию: $errorMessage');
    }
  }

  /// Финализирует книгу
  /// POST /books/{book_id}/finalize
  Future<Book> finalizeBook(String bookId) async {
    try {
      final response = await _dio.post('/books/$bookId/finalize');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Book.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Не удалось финализировать книгу: статус ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.message ?? 
                          'Неизвестная ошибка';
      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт.');
      }
      if (statusCode == 404) {
        throw Exception('Книга не найдена.');
      }
      if (statusCode != null && statusCode >= 400) {
        throw Exception('Ошибка финализации: $errorMessage');
      }
      rethrow;
    }
  }

  /// Получает книги для конкретного ребёнка
  /// GET /books?child_id={childId}
  Future<List<Book>> getBooksForChild(String childId) async {
    try {
      final response = await _dio.get('/books', queryParameters: {
        'child_id': childId,
      });
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as List;
        return data.map((json) => Book.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 401) {
        return [];
      }
      rethrow;
    } catch (e) {
      print('[BackendApi] getBooksForChild: Ошибка: $e');
      return [];
    }
  }

  /// Получает одну книгу по ID
  Future<Book> getBook(String bookId) async {
    try {
      print('[BackendApi] getBook: Запрос книги с ID: $bookId');
      final response = await _dio.get('/books/$bookId');
      print('[BackendApi] getBook: Статус ответа: ${response.statusCode}');
      
      if (response.statusCode == 200 && response.data != null) {
        try {
          final data = response.data as Map<String, dynamic>;
          print('[BackendApi] getBook: Данные получены, ключи: ${data.keys.toList()}');
          print('[BackendApi] getBook: id=${data['id']}, title=${data['title']}, status=${data['status']}');
          print('[BackendApi] getBook: is_paid=${data['is_paid']} (тип: ${data['is_paid'].runtimeType})');
          print('[BackendApi] getBook: final_pdf_url=${data['final_pdf_url']}');
          
          // Проверяем обязательные поля перед парсингом
          if (data['id'] == null) {
            throw Exception('Отсутствует обязательное поле: id');
          }
          if (data['child_id'] == null) {
            throw Exception('Отсутствует обязательное поле: child_id');
          }
          if (data['title'] == null) {
            throw Exception('Отсутствует обязательное поле: title');
          }
          if (data['created_at'] == null) {
            throw Exception('Отсутствует обязательное поле: created_at');
          }
          
          final book = Book.fromJson(data);
          print('[BackendApi] getBook: Книга успешно распарсена: ${book.title}');
          print('[BackendApi] getBook: book.isPaid после парсинга: ${book.isPaid}');
          print('[BackendApi] getBook: book.finalPdfUrl после парсинга: ${book.finalPdfUrl}');
          return book;
        } catch (e) {
          print('[BackendApi] getBook: ОШИБКА парсинга книги: $e');
          print('[BackendApi] getBook: Данные ответа: ${response.data}');
          rethrow;
        }
      }
      throw Exception('Книга не найдена: статус ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      print('[BackendApi] getBook: DioException, статус: $statusCode');
      if (statusCode == 404) {
        print('[BackendApi] getBook: Книга не найдена (404)');
        throw Exception('Книга не найдена');
      }
      if (statusCode == 401) {
        print('[BackendApi] getBook: Требуется авторизация (401)');
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт.');
      }
      print('[BackendApi] getBook: Неожиданная ошибка DioException: ${e.message}');
      rethrow;
    } catch (e) {
      print('[BackendApi] getBook: Неожиданная ошибка: $e');
      print('[BackendApi] getBook: Тип ошибки: ${e.runtimeType}');
      rethrow;
    }
  }

  // ==================== PAYMENT ====================

  /// Создать платёж для книги
  /// POST /payments/create
  /// Возвращает URL для оплаты (если есть платёжная система) или null (демо-режим)
  Future<String?> createPayment(String bookId) async {
    try {
      print('[BackendApi] [API REQUEST] POST /payments/create');
      print('[BackendApi] Request data: {book_id: $bookId}');
      
      final response = await _dio.post(
        '/payments/create',
        data: {'book_id': bookId},
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return data['payment_url'] as String?;
      }
      return null;
    } on DioException catch (e) {
      print('[BackendApi] Payment create error: ${e.message}');
      // В демо-режиме возвращаем null - будет имитация оплаты
      return null;
    }
  }

  /// Подтвердить оплату книги (для демо или webhook)
  /// POST /payments/confirm
  Future<bool> confirmPayment(String bookId) async {
    try {
      print('[BackendApi] [API REQUEST] POST /payments/confirm');
      print('[BackendApi] Request data: {book_id: $bookId}');
      
      final response = await _dio.post(
        '/payments/confirm',
        data: {'book_id': bookId},
      );
      
      return response.statusCode == 200;
    } on DioException catch (e) {
      print('[BackendApi] Payment confirm error: ${e.message}');
      // В демо-режиме считаем что оплата прошла
      return true;
    }
  }

  /// Проверить статус оплаты книги
  /// GET /payments/status/{book_id}
  Future<bool> checkPaymentStatus(String bookId) async {
    try {
      print('[BackendApi] [API REQUEST] GET /payments/status/$bookId');
      
      final response = await _dio.get('/payments/status/$bookId');
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return data['is_paid'] == true;
      }
      return false;
    } on DioException catch (e) {
      print('[BackendApi] Payment status error: ${e.message}');
      return false;
    }
  }

  // ==================== PRINT ORDERS ====================

  /// Создать платёж для заказа на печать
  /// POST /payments/create_print_order
  /// Возвращает URL для оплаты или null (демо-режим)
  Future<String?> createPaymentForPrintOrder({
    required String bookId,
    required int amount,
    required Map<String, dynamic> orderData,
  }) async {
    try {
      print('[BackendApi] [API REQUEST] POST /payments/create_print_order');
      print('[BackendApi] Request data: {book_id: $bookId, amount: $amount}');
      
      final response = await _dio.post(
        '/payments/create_print_order',
        data: {
          'book_id': bookId,
          'amount': amount,
          'order_data': orderData,
        },
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return data['payment_url'] as String?;
      }
      return null;
    } on DioException catch (e) {
      print('[BackendApi] Print order payment create error: ${e.message}');
      // В демо-режиме возвращаем null - будет имитация оплаты
      return null;
    }
  }

  /// Подтвердить оплату заказа на печать (для демо или webhook)
  /// POST /payments/confirm_print_order
  Future<bool> confirmPaymentForPrintOrder({
    required String bookId,
    required Map<String, dynamic> orderData,
  }) async {
    try {
      print('[BackendApi] [API REQUEST] POST /payments/confirm_print_order');
      print('[BackendApi] Request data: {book_id: $bookId, order_data: ...}');
      
      final response = await _dio.post(
        '/payments/confirm_print_order',
        data: {
          'book_id': bookId,
          'order_data': orderData, // Передаем order_data для подтверждения
        },
      );
      
      return response.statusCode == 200;
    } on DioException catch (e) {
      print('[BackendApi] Print order payment confirm error: ${e.message}');
      // В демо-режиме считаем что оплата прошла
      return true;
    }
  }

  /// Создать заказ на печать книги
  /// POST /orders/print
  /// 
  /// ВАЖНО: Этот метод должен вызываться ПОСЛЕ успешной оплаты заказа на печать!
  /// 
  /// После успешного создания заказа бэкенд ДОЛЖЕН:
  /// 1. Отправить письмо на email производителя с параметрами заказа:
  ///    - Название книги (book_title)
  ///    - Размер (size)
  ///    - Количество страниц (pages)
  ///    - Тип переплёта (binding)
  ///    - Тип упаковки (packaging)
  ///    - Итоговая стоимость (total_price)
  ///    - Данные клиента (customer_name, customer_phone, customer_address)
  ///    - Комментарий (comment, если есть)
  /// 
  /// 2. Отправить уведомление в Telegram производителя с теми же параметрами
  /// 
  /// Если уведомления не отправляются, это проблема бэкенда!
  Future<Map<String, dynamic>> createPrintOrder({
    required String bookId,
    required String bookTitle,
    required String size,
    required int pages,
    required String binding,
    required String packaging,
    required int totalPrice,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    String? comment,
  }) async {
    try {
      print('[BackendApi] [API REQUEST] POST /orders/print');
      print('[BackendApi] Order data: bookId=$bookId, size=$size, pages=$pages, binding=$binding, packaging=$packaging, total=$totalPrice');
      
      final orderData = {
        'book_id': bookId,
        'book_title': bookTitle,
        'size': size,
        'pages': pages,
        'binding': binding,
        'packaging': packaging,
        'total_price': totalPrice,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_address': customerAddress,
        'comment': comment ?? '',
        'created_at': DateTime.now().toIso8601String(),
      };
      
      final response = await _dio.post(
        '/orders/print',
        data: orderData,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[BackendApi] Print order created successfully');
        return response.data as Map<String, dynamic>;
      }
      
      throw Exception('Не удалось создать заказ: статус ${response.statusCode}');
    } on DioException catch (e) {
      print('[BackendApi] Print order error: ${e.message}');
      
      // В демо-режиме возвращаем успешный ответ
      if (e.response?.statusCode == 404) {
        print('[BackendApi] Demo mode: simulating successful order');
        return {
          'status': 'success',
          'order_id': 'demo_${DateTime.now().millisecondsSinceEpoch}',
          'message': 'Заказ оформлен (демо-режим)',
        };
      }
      
      rethrow;
    }
  }

  // ==================== SUBSCRIPTION ====================

  /// Проверить статус подписки
  /// GET /subscription/status
  Future<Map<String, dynamic>> checkSubscription() async {
    try {
      print('[BackendApi] [API REQUEST] GET /subscription/status');
      
      final response = await _dio.get('/subscription/status');
      
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return {'is_subscribed': false};
    } on DioException catch (e) {
      print('[BackendApi] Subscription check error: ${e.message}');
      // В демо-режиме возвращаем false
      return {'is_subscribed': false};
    }
  }

  /// Оформить подписку
  /// POST /subscription/create
  Future<Map<String, dynamic>> createSubscription() async {
    try {
      print('[BackendApi] [API REQUEST] POST /subscription/create');
      
      final response = await _dio.post(
        '/subscription/create',
        data: {'price': 199},
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[BackendApi] Subscription created successfully');
        return response.data as Map<String, dynamic>;
      }
      
      throw Exception('Не удалось оформить подписку');
    } on DioException catch (e) {
      print('[BackendApi] Subscription create error: ${e.message}');
      
      // В демо-режиме имитируем успешную подписку
      if (e.response?.statusCode == 404) {
        print('[BackendApi] Demo mode: simulating successful subscription');
        return {
          'status': 'success',
          'is_subscribed': true,
          'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        };
      }
      
      rethrow;
    }
  }

  // Health check
  Future<bool> checkBackend() async {
    try {
      final res = await _dio.get(
        '/health/db',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ==================== SUPPORT MESSAGES ====================

  /// Отправить сообщение поддержки
  /// POST /support/send_message
  /// 
  /// ВАЖНО: После успешной отправки бэкенд ДОЛЖЕН:
  /// 1. Отправить письмо на email производителя с параметрами сообщения:
  ///    - Имя отправителя (name)
  ///    - Email отправителя (email)
  ///    - Тип обращения (type: suggestion/bug/question)
  ///    - Сообщение (message)
  /// 
  /// 2. Отправить уведомление в Telegram производителя с теми же параметрами
  /// 
  /// Если уведомления не отправляются, это проблема бэкенда!
  /// Отправка нового сообщения поддержки
  /// Возвращает message_id нового сообщения
  Future<String> sendSupportMessage({
    required String name,
    required String email,
    required String type, // suggestion, bug, question
    required String message,
  }) async {
    try {
      print('[BackendApi] [API REQUEST] POST /support/send_message');
      print('[BackendApi] Support message data: name=$name, email=$email, type=$type');
      
      final response = await _dio.post(
        '/support/send_message',
        data: {
          'name': name,
          'email': email,
          'type': type,
          'message': message,
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final messageId = data['message_id']?.toString();
        
        if (messageId != null && messageId.isNotEmpty) {
          print('[BackendApi] Support message sent successfully, message_id: $messageId');
          return messageId;
        } else {
          print('[BackendApi] Warning: message_id not found in response: $data');
          // Если message_id нет, возвращаем пустую строку (для обратной совместимости)
          return '';
        }
      }
      throw Exception('Неожиданный статус ответа: ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.message ?? 
                          'Неизвестная ошибка';
      
      print('[BackendApi] Support message send error: ${e.message}');
      
      if (statusCode == 400 || statusCode == 422) {
        throw Exception('Ошибка запроса: $errorMessage');
      }
      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт.');
      }
      rethrow;
    } catch (e) {
      print('[BackendApi] Support message send error: ${e.toString()}');
      rethrow;
    }
  }

  /// Получить список всех сообщений текущего пользователя
  Future<List<SupportMessage>> getSupportMessages({
    String? status,
    int? limit,
    int? offset,
  }) async {
    try {
      print('[BackendApi] [API REQUEST] GET /support/messages');
      
      final queryParameters = <String, dynamic>{};
      if (status != null) queryParameters['status'] = status;
      if (limit != null) queryParameters['limit'] = limit;
      if (offset != null) queryParameters['offset'] = offset;
      
      final response = await _dio.get(
        '/support/messages',
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        final messagesList = data['messages'] as List<dynamic>? ?? [];
        
        final messages = messagesList
            .map((json) => SupportMessage.fromJson(json as Map<String, dynamic>))
            .toList();
        
        print('[BackendApi] Support messages retrieved successfully, count: ${messages.length}');
        return messages;
      }
      throw Exception('Неожиданный статус ответа: ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.message ?? 
                          'Неизвестная ошибка';
      
      print('[BackendApi] Get support messages error: ${e.message}');
      
      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт.');
      }
      if (statusCode == 404) {
        return []; // Если нет сообщений, возвращаем пустой список
      }
      rethrow;
    } catch (e) {
      print('[BackendApi] Get support messages error: ${e.toString()}');
      rethrow;
    }
  }

  /// Получить конкретное сообщение со всеми ответами
  Future<SupportMessageDetail> getSupportMessageDetail(String messageId) async {
    try {
      print('[BackendApi] [API REQUEST] GET /support/messages/$messageId');
      
      final response = await _dio.get('/support/messages/$messageId');
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        final message = SupportMessage.fromJson(data['message'] as Map<String, dynamic>);
        final repliesList = data['replies'] as List<dynamic>? ?? [];
        
        final replies = repliesList
            .map((json) => SupportMessageReply.fromJson(json as Map<String, dynamic>))
            .toList();
        
        final unreadCount = data['unread_replies_count'] as int? ?? 0;
        
        print('[BackendApi] Support message detail retrieved successfully, replies: ${replies.length}, unread: $unreadCount');
        return SupportMessageDetail(
          message: message,
          replies: replies,
          unreadRepliesCount: unreadCount,
        );
      }
      throw Exception('Неожиданный статус ответа: ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.message ?? 
                          'Неизвестная ошибка';
      
      print('[BackendApi] Get support message detail error: ${e.message}');
      
      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт.');
      }
      if (statusCode == 404) {
        throw Exception('Сообщение не найдено');
      }
      rethrow;
    } catch (e) {
      print('[BackendApi] Get support message detail error: ${e.toString()}');
      rethrow;
    }
  }

  /// Отправить ответ пользователя на сообщение
  Future<String> sendSupportMessageReply({
    required String messageId,
    required String message,
  }) async {
    try {
      print('[BackendApi] [API REQUEST] POST /support/messages/$messageId/reply');
      
      final response = await _dio.post(
        '/support/messages/$messageId/reply',
        data: {
          'message': message,
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final replyId = data['reply_id']?.toString() ?? '';
        
        print('[BackendApi] Support message reply sent successfully, reply_id: $replyId');
        return replyId;
      }
      throw Exception('Неожиданный статус ответа: ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.message ?? 
                          'Неизвестная ошибка';
      
      print('[BackendApi] Send support message reply error: ${e.message}');
      
      if (statusCode == 400 || statusCode == 422) {
        throw Exception('Ошибка запроса: $errorMessage');
      }
      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт.');
      }
      if (statusCode == 404) {
        throw Exception('Сообщение не найдено');
      }
      rethrow;
    } catch (e) {
      print('[BackendApi] Send support message reply error: ${e.toString()}');
      rethrow;
    }
  }

  /// Пометить ответ администрации как прочитанный
  Future<void> markSupportMessageReplyAsRead({
    required String messageId,
    required String replyId,
  }) async {
    try {
      print('[BackendApi] [API REQUEST] PUT /support/messages/$messageId/replies/$replyId/read');
      
      final response = await _dio.put('/support/messages/$messageId/replies/$replyId/read');
      
      if (response.statusCode == 200) {
        print('[BackendApi] Support message reply marked as read successfully');
        return;
      }
      throw Exception('Неожиданный статус ответа: ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.message ?? 
                          'Неизвестная ошибка';
      
      print('[BackendApi] Mark support message reply as read error: ${e.message}');
      
      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт.');
      }
      if (statusCode == 404) {
        throw Exception('Сообщение или ответ не найдены');
      }
      rethrow;
    } catch (e) {
      print('[BackendApi] Mark support message reply as read error: ${e.toString()}');
      rethrow;
    }
  }

  /// Обновить статус сообщения
  Future<void> updateSupportMessageStatus({
    required String messageId,
    required String status, // 'closed'
  }) async {
    try {
      print('[BackendApi] [API REQUEST] PUT /support/messages/$messageId/status');
      
      final response = await _dio.put(
        '/support/messages/$messageId/status',
        data: {
          'status': status,
        },
      );
      
      if (response.statusCode == 200) {
        print('[BackendApi] Support message status updated successfully');
        return;
      }
      throw Exception('Неожиданный статус ответа: ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.message ?? 
                          'Неизвестная ошибка';
      
      print('[BackendApi] Update support message status error: ${e.message}');
      
      if (statusCode == 400 || statusCode == 422) {
        throw Exception('Ошибка запроса: $errorMessage');
      }
      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт.');
      }
      if (statusCode == 404) {
        throw Exception('Сообщение не найдено');
      }
      rethrow;
    } catch (e) {
      print('[BackendApi] Update support message status error: ${e.toString()}');
      rethrow;
    }
  }

  /// Удалить сообщение поддержки
  /// Примечание: Если бэкенд не поддерживает DELETE, возможно нужно использовать PUT с status='deleted' или другой метод
  Future<void> deleteSupportMessage(String messageId) async {
    try {
      print('[BackendApi] [API REQUEST] DELETE /support/messages/$messageId');
      
      final response = await _dio.delete('/support/messages/$messageId');
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        print('[BackendApi] Support message deleted successfully');
        return;
      }
      throw Exception('Неожиданный статус ответа: ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?['detail']?.toString() ?? 
                          e.response?.data?['message']?.toString() ?? 
                          e.message ?? 
                          'Неизвестная ошибка';
      
      print('[BackendApi] Delete support message error: ${e.message}, status: $statusCode');
      
      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт.');
      }
      if (statusCode == 404) {
        throw Exception('Сообщение не найдено');
      }
      if (statusCode == 403) {
        throw Exception('Нет прав на удаление этого сообщения');
      }
      if (statusCode == 405) {
        // Метод не поддерживается - возможно бэкенд использует другой способ удаления
        // Пробуем использовать PUT с status='deleted' как альтернативу
        try {
          print('[BackendApi] DELETE method not supported, trying PUT with status=deleted');
          await updateSupportMessageStatus(messageId: messageId, status: 'deleted');
          print('[BackendApi] Support message marked as deleted successfully');
          return;
        } catch (updateError) {
          throw Exception('Удаление не поддерживается сервером. Обратитесь в поддержку.');
        }
      }
      rethrow;
    } catch (e) {
      print('[BackendApi] Delete support message error: ${e.toString()}');
      rethrow;
    }
  }
}

/// Класс для хранения деталей сообщения поддержки с ответами
class SupportMessageDetail {
  final SupportMessage message;
  final List<SupportMessageReply> replies;
  final int unreadRepliesCount;

  SupportMessageDetail({
    required this.message,
    required this.replies,
    required this.unreadRepliesCount,
  });
}

