import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as io;
import 'package:path/path.dart' as path;
import 'api_client.dart';
import '../models/child.dart';
import '../utils/image_compressor.dart';
import '../models/book.dart';
import '../models/scene.dart';
import '../models/task_status.dart';
import '../models/generate_full_book_response.dart';

final backendApiProvider = Provider<BackendApi>((ref) {
  final dio = ref.watch(dioProvider);
  return BackendApi(dio);
});

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
    required String interests,
    required String fears,
    required String character,
    required String moral,
    String? faceUrl,
    List<io.File>? photos,
  }) async {
    try {
      print('[BackendApi] createChild: Создание ребенка');
      
      // ШАГ 1: Сначала создаем ребенка БЕЗ фото
      final response = await _dio.post(
        '/children',
        data: {
          'name': name,
          'age': age,
          'interests': interests,
          'fears': fears,
          'character': character,
          'moral': moral,
          if (faceUrl != null) 'face_url': faceUrl,
        },
      );
      
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
            return Child.fromJson(json as Map<String, dynamic>);
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
        print('[BackendApi] updateChild: Начинаем загрузку ${photos.length} фотографий через /children/$id/photos');
        
        try {
          // Загружаем первую фотографию
          // ВАЖНО: uploadChildPhoto отправляет POST /children/{id}/photos
          // child_id передается ТОЛЬКО в URL, НЕ в FormData
          final faceUrlFromUpload = await uploadChildPhoto(photos.first, id);
          
          // Обновляем faceUrl в модели через copyWith
          final childWithPhoto = updatedChild.copyWith(faceUrl: faceUrlFromUpload);
          
          print('[BackendApi] updateChild: Фотография загружена, face_url обновлен: $faceUrlFromUpload');
          
          return childWithPhoto;
        } catch (e) {
          print('[BackendApi] updateChild: ОШИБКА загрузки фотографии: $e');
          print('[BackendApi] updateChild: Возвращаем ребенка без обновления фото');
          // Продолжаем с обновленным ребенком, даже если фото не загрузилось
          // Можно загрузить фото позже
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
      final response = await _dio.get('/books/$bookId/scenes');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        List<dynamic> scenesList;
        
        // Handle both response shapes: List OR {scenes: List}
        if (data is List) {
          scenesList = data;
        } else if (data is Map<String, dynamic> && data.containsKey('scenes')) {
          final scenesValue = data['scenes'];
          if (scenesValue is List) {
            scenesList = scenesValue;
          } else {
            print('[BackendApi] getBookScenes: ОШИБКА - поле scenes не является List. Тип: ${scenesValue.runtimeType}, Значение: $scenesValue');
            return [];
          }
        } else {
          print('[BackendApi] getBookScenes: ОШИБКА - неожиданный формат ответа. Тип: ${data.runtimeType}, Значение: $data');
          return [];
        }
        
        return scenesList
            .map((json) {
              try {
                // Безопасный парсинг с обработкой null значений
                final sceneData = json as Map<String, dynamic>;
                // Преобразуем все потенциально null поля в безопасные строки
                final safeData = <String, dynamic>{
                  'id': sceneData['id']?.toString() ?? '',
                  'book_id': sceneData['book_id']?.toString() ?? '',
                  'order': sceneData['order'] ?? 0,
                  'short_summary': sceneData['short_summary']?.toString() ?? '',
                  'image_prompt': sceneData['image_prompt']?.toString(),
                  'draft_url': sceneData['draft_url']?.toString(),
                  'final_url': sceneData['final_url']?.toString(),
                };
                return Scene.fromJson(safeData);
              } catch (e) {
                print('[BackendApi] getBookScenes: Ошибка парсинга сцены: $e');
                print('[BackendApi] getBookScenes: Данные сцены: $json');
                // Возвращаем пустую сцену вместо rethrow, чтобы не ломать весь список
                return Scene(
                  id: json['id']?.toString() ?? '0',
                  bookId: json['book_id']?.toString() ?? '',
                  order: (json['order'] as num?)?.toInt() ?? 0,
                  shortSummary: json['short_summary']?.toString() ?? '',
                  imagePrompt: json['image_prompt']?.toString(),
                  draftUrl: json['draft_url']?.toString(),
                  finalUrl: json['final_url']?.toString(),
                );
              }
            })
            .where((scene) => scene.id.isNotEmpty && scene.bookId.isNotEmpty)
            .toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 401) {
        print('[BackendApi] getBookScenes: Endpoint не найден или требуется авторизация');
        return [];
      }
      rethrow;
    } catch (e) {
      print('[BackendApi] getBookScenes: Неожиданная ошибка: $e');
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
      
      throw Exception('Ошибка удаления книги: $errorMessage');
    } catch (e) {
      print('[BackendApi] deleteBook: Неожиданная ошибка: $e');
      rethrow;
    }
  }

  /// POST /books/generate_full_book
  /// Генерирует полную книгу для указанного ребенка с указанным стилем
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
  }) async {
    try {
      print('[BackendApi] [API REQUEST] POST /books/generate_full_book');
      print('[BackendApi] Request data: {child_id: $childId, style: $style}');
      
      final response = await _dio.post(
        '/books/generate_full_book',
        data: {
          'child_id': childId,
          'style': style,
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
        
        // Проверяем наличие обязательных полей
        if (data['id'] == null || data['status'] == null) {
          throw Exception('Некорректный ответ от сервера: отсутствуют обязательные поля (id или status)');
        }
        
        // Безопасный парсинг - поля могут отсутствовать, но не должны быть null для обязательных
        try {
          return TaskStatus.fromJson(data);
        } catch (e) {
          throw Exception('Ошибка парсинга ответа от сервера: $e');
        }
      }
      throw Exception('Не удалось получить статус задачи: статус ${response.statusCode}');
    } on DioException catch (e) {
      print('[BackendApi] [API ERROR] DioException: ${e.message}');
      print('[BackendApi] [API ERROR] URL: ${e.requestOptions.uri}');
      if (e.response?.statusCode == 404) {
        throw Exception('Задача не найдена. Проверьте правильность task_id или обратитесь к администратору.');
      }
      if (e.response?.statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт заново.');
      }
      rethrow;
    } catch (e) {
      if (e.toString().contains('type') && e.toString().contains('Null')) {
        throw Exception('Ошибка парсинга ответа от сервера: некорректный формат данных');
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

  /// Обновляет текст сцены
  /// POST /books/{book_id}/update_text
  Future<Scene> updateText({
    required String bookId,
    required int sceneIndex,
    required String instruction,
  }) async {
    try {
      final response = await _dio.post(
        '/books/$bookId/update_text',
        data: {
          'scene_index': sceneIndex,
          'instruction': instruction,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Scene.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Не удалось обновить текст: статус ${response.statusCode}');
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
        throw Exception('Книга или сцена не найдена.');
      }
      if (statusCode != null && statusCode >= 400) {
        throw Exception('Ошибка обновления текста: $errorMessage');
      }
      rethrow;
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
      final response = await _dio.get('/books/$bookId');
      if (response.statusCode == 200 && response.data != null) {
        return Book.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Книга не найдена: статус ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 404) {
        throw Exception('Книга не найдена');
      }
      if (statusCode == 401) {
        throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт.');
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
}

