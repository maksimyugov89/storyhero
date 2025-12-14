import 'package:dio/dio.dart';

/// Результат анализа ошибки
class ErrorAnalysis {
  final String userFriendlyMessage;
  final String? technicalDetails;
  final bool isNetworkError;
  final bool isServerError;
  final int? statusCode;

  const ErrorAnalysis({
    required this.userFriendlyMessage,
    this.technicalDetails,
    this.isNetworkError = false,
    this.isServerError = false,
    this.statusCode,
  });
}

/// Утилита для анализа ошибок и преобразования их в дружелюбные сообщения
class ErrorAnalyzer {
  /// Анализирует ошибку и возвращает дружелюбное сообщение для пользователя
  static ErrorAnalysis analyze(dynamic error) {
    // DioException - ошибки сети и HTTP
    if (error is DioException) {
      return _analyzeDioException(error);
    }

    // Exception с текстом ошибки
    if (error is Exception) {
      return _analyzeException(error);
    }

    // Обычная ошибка
    final errorString = error.toString().toLowerCase();

    // Проверяем на сетевые ошибки по тексту
    if (_isNetworkErrorText(errorString)) {
      return const ErrorAnalysis(
        userFriendlyMessage: 'Проверьте интернет-соединение.',
        isNetworkError: true,
      );
    }

    // Проверяем на ошибки сервера по тексту
    if (_isServerErrorText(errorString)) {
      return const ErrorAnalysis(
        userFriendlyMessage: 'Сервер временно недоступен. Мы уже чиним магию! Попробуйте через минуту.',
        isServerError: true,
      );
    }

    // Общая ошибка
    return ErrorAnalysis(
      userFriendlyMessage: 'Произошла ошибка. Попробуйте ещё раз.',
      technicalDetails: error.toString(),
    );
  }

  /// Анализирует DioException
  static ErrorAnalysis _analyzeDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final errorMessage = error.message?.toLowerCase() ?? '';
    final errorType = error.type;

    // Ошибки сервера (500, 502, 503, 504)
    if (statusCode != null && (statusCode == 500 || statusCode == 502 || statusCode == 503 || statusCode == 504)) {
      return ErrorAnalysis(
        userFriendlyMessage: 'Сервер временно недоступен. Мы уже чиним магию! Попробуйте через минуту.',
        technicalDetails: 'HTTP $statusCode: ${error.message}',
        isServerError: true,
        statusCode: statusCode,
      );
    }

    // Ошибки сети
    if (errorType == DioExceptionType.connectionTimeout ||
        errorType == DioExceptionType.sendTimeout ||
        errorType == DioExceptionType.receiveTimeout ||
        errorType == DioExceptionType.connectionError) {
      return ErrorAnalysis(
        userFriendlyMessage: 'Проверьте интернет-соединение.',
        technicalDetails: '${errorType.toString()}: ${error.message}',
        isNetworkError: true,
      );
    }

    // DNS ошибки и SocketException (Name or service not known)
    if (errorMessage.contains('name or service not known') ||
        errorMessage.contains('failed host lookup') ||
        errorMessage.contains('socketexception') ||
        errorMessage.contains('socket exception') ||
        errorType == DioExceptionType.unknown) {
      // Проверяем, не является ли это ошибкой сервера (500 с DNS проблемой)
      if (statusCode != null && statusCode >= 500) {
        return ErrorAnalysis(
          userFriendlyMessage: 'Сервер временно недоступен. Мы уже чиним магию! Попробуйте через минуту.',
          technicalDetails: 'DNS/Connection error: ${error.message}',
          isServerError: true,
          statusCode: statusCode,
        );
      }
      
      // SocketException и DNS ошибки - проблемы с интернетом
      return ErrorAnalysis(
        userFriendlyMessage: 'Проверьте интернет-соединение.',
        technicalDetails: 'DNS/Connection error: ${error.message}',
        isNetworkError: true,
      );
    }

    // 401 - неавторизован (обрабатывается в AuthInterceptor, но показываем дружелюбное сообщение)
    if (statusCode == 401) {
      return ErrorAnalysis(
        userFriendlyMessage: 'Требуется авторизация. Пожалуйста, войдите в аккаунт заново.',
        technicalDetails: 'HTTP 401: ${error.message}',
        statusCode: 401,
      );
    }

    // 402 - недостаточно средств
    if (statusCode == 402) {
      return ErrorAnalysis(
        userFriendlyMessage: 'Недостаточно средств на DeepSeek, попробуйте позже.',
        technicalDetails: 'HTTP 402: ${error.message}',
        statusCode: 402,
      );
    }

    // 404 - не найдено
    if (statusCode == 404) {
      return ErrorAnalysis(
        userFriendlyMessage: 'Запрашиваемый ресурс не найден.',
        technicalDetails: 'HTTP 404: ${error.message}',
        statusCode: 404,
      );
    }

    // 403 - запрещено
    if (statusCode == 403) {
      return ErrorAnalysis(
        userFriendlyMessage: 'У вас нет доступа к этому ресурсу.',
        technicalDetails: 'HTTP 403: ${error.message}',
        statusCode: 403,
      );
    }

    // Другие HTTP ошибки (400, 422 и т.д.)
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      final detail = error.response?.data?['detail']?.toString() ?? 
                    error.response?.data?['message']?.toString() ?? 
                    error.message;
      
      return ErrorAnalysis(
        userFriendlyMessage: detail ?? 'Произошла ошибка при выполнении запроса.',
        technicalDetails: 'HTTP $statusCode: ${error.message}',
        statusCode: statusCode,
      );
    }

    // Неизвестная ошибка DioException
    return ErrorAnalysis(
      userFriendlyMessage: 'Ошибка соединения с сервером. Попробуйте ещё раз.',
      technicalDetails: '${errorType.toString()}: ${error.message}',
      isNetworkError: true,
    );
  }

  /// Анализирует Exception
  static ErrorAnalysis _analyzeException(Exception error) {
    final errorString = error.toString().toLowerCase();

    // Проверяем на SocketException явно
    if (errorString.contains('socketexception') || 
        errorString.contains('socket exception')) {
      return const ErrorAnalysis(
        userFriendlyMessage: 'Проверьте интернет-соединение.',
        isNetworkError: true,
        technicalDetails: null,
      );
    }

    // Проверяем на сетевые ошибки
    if (_isNetworkErrorText(errorString)) {
      return const ErrorAnalysis(
        userFriendlyMessage: 'Проверьте интернет-соединение.',
        isNetworkError: true,
        technicalDetails: null,
      );
    }

    // Проверяем на ошибки сервера
    if (_isServerErrorText(errorString)) {
      return const ErrorAnalysis(
        userFriendlyMessage: 'Сервер временно недоступен. Мы уже чиним магию! Попробуйте через минуту.',
        isServerError: true,
        technicalDetails: null,
      );
    }

    // Извлекаем сообщение из Exception
    final message = error.toString();
    
    // Если сообщение уже дружелюбное, используем его
    if (message.contains('Требуется авторизация') ||
        message.contains('Пожалуйста, войдите') ||
        message.contains('Проверьте соединение')) {
      return ErrorAnalysis(
        userFriendlyMessage: message,
        technicalDetails: null,
      );
    }

    // Общая ошибка
    return ErrorAnalysis(
      userFriendlyMessage: 'Произошла ошибка. Попробуйте ещё раз.',
      technicalDetails: message,
    );
  }

  /// Проверяет, является ли текст ошибкой сети
  static bool _isNetworkErrorText(String errorText) {
    return errorText.contains('connection') ||
           errorText.contains('network') ||
           errorText.contains('internet') ||
           errorText.contains('timeout') ||
           errorText.contains('failed host lookup') ||
           errorText.contains('name or service not known') ||
           errorText.contains('socketexception') ||
           errorText.contains('socket exception') ||
           errorText.contains('no internet') ||
           errorText.contains('unreachable');
  }

  /// Проверяет, является ли текст ошибкой сервера
  static bool _isServerErrorText(String errorText) {
    return errorText.contains('500') ||
           errorText.contains('502') ||
           errorText.contains('503') ||
           errorText.contains('504') ||
           errorText.contains('internal server error') ||
           errorText.contains('bad gateway') ||
           errorText.contains('service unavailable') ||
           errorText.contains('gateway timeout');
  }
}

