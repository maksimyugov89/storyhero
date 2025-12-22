import 'package:freezed_annotation/freezed_annotation.dart';
import 'book_generation_step.dart';

part 'task_status.freezed.dart';
part 'task_status.g.dart';

/// Конвертер для преобразования ID из int (PostgreSQL) или String (UUID) в String
String _taskStatusIdToString(dynamic value) {
  return value.toString();
}

/// Модель прогресса генерации книги согласно API документации
@freezed
class TaskProgress with _$TaskProgress {
  const factory TaskProgress({
    String? stage, // "starting", "creating_plot", "plot_ready", etc.
    @JsonKey(name: 'current_step') int? currentStep, // номер текущего шага
    @JsonKey(name: 'total_steps') int? totalSteps, // общее количество шагов (7)
    String? message, // сообщение для пользователя
    @JsonKey(name: 'book_id') String? bookId, // ID книги (когда известен)
    @JsonKey(name: 'images_generated') int? imagesGenerated, // количество сгенерированных изображений
    @JsonKey(name: 'total_images') int? totalImages, // общее количество изображений
  }) = _TaskProgress;

  factory TaskProgress.fromJson(Map<String, dynamic> json) =>
      _$TaskProgressFromJson(json);
}

@freezed
class TaskStatus with _$TaskStatus {
  const factory TaskStatus({
    @JsonKey(fromJson: _taskStatusIdToString) required String id,
    required String status, // "running", "completed", "failed", "lost", etc.
    @JsonKey(name: 'book_id') String? bookId, // для обратной совместимости
    String? error,
    TaskProgress? progress, // объект прогресса согласно API документации
    Map<String, dynamic>? meta, // метаданные, включая book_id при status='lost'
    // Старые поля для обратной совместимости
    @JsonKey(name: 'current_step') String? currentStep,
    @JsonKey(includeFromJson: false, includeToJson: false) double? progressPercent, // вычисляемое поле
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'started_at') String? startedAt,
  }) = _TaskStatus;

  factory TaskStatus.fromJson(Map<String, dynamic> json) =>
      _$TaskStatusFromJson(json);
}

/// Расширение для TaskStatus с поддержкой BookGenerationStep
extension TaskStatusExtension on TaskStatus {
  /// Получить текущий этап генерации как enum
  /// Всегда возвращает валидный enum, fallback на text если неизвестен
  BookGenerationStep get generationStep {
    // Сначала проверяем progress.stage (новый формат API)
    if (progress?.stage != null) {
      final step = BookGenerationStep.fromString(progress!.stage);
      if (step != null) return step;
    }
    
    // Затем проверяем currentStep (старый формат для обратной совместимости)
    if (currentStep != null) {
      final step = BookGenerationStep.fromString(currentStep);
      if (step != null) return step;
    }
    
    // Fallback: определяем по status
    if (status == 'completed' || status == 'done' || status == 'success') {
      return BookGenerationStep.done;
    }
    if (status == 'failed' || status == 'error') {
      return BookGenerationStep.text; // Fallback для ошибок
    }
    if (status == 'running' || status == 'in_progress') {
      return BookGenerationStep.text; // Начальный этап
    }
    return BookGenerationStep.text; // Default fallback
  }

  /// Получить статус генерации
  BookGenerationStatus get generationStatus {
    final step = generationStep; // Теперь всегда валидный enum
    
    // Используем message из progress, если доступно
    final message = progress?.message ?? 
                    currentStep ?? 
                    progress?.stage ?? 
                    status;
    
    // Вычисляем прогресс из current_step и total_steps
    double? calculatedProgress;
    if (progress?.currentStep != null && progress?.totalSteps != null) {
      calculatedProgress = (progress!.currentStep! / progress!.totalSteps!) * 100;
    }
    
    return BookGenerationStatus(
      step: step,
      message: message ?? 'Генерация книги...',
      progress: calculatedProgress,
    );
  }
  
  /// Получить ID книги (из progress.book_id, meta.book_id или bookId)
  String? get bookIdValue => progress?.bookId ?? meta?['book_id'] ?? bookId;
  
  /// Проверить, является ли задача потерянной
  bool get isLost => status == 'lost';
  
  /// Получить информацию о прогрессе генерации изображений
  String? get imagesProgress {
    if (progress?.imagesGenerated != null && progress?.totalImages != null) {
      return '${progress!.imagesGenerated}/${progress!.totalImages}';
    }
    return null;
  }
}

