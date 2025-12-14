import 'package:freezed_annotation/freezed_annotation.dart';
import 'book_generation_step.dart';

part 'task_status.freezed.dart';
part 'task_status.g.dart';

/// Конвертер для преобразования ID из int (PostgreSQL) или String (UUID) в String
String _taskStatusIdToString(dynamic value) {
  return value.toString();
}

@freezed
class TaskStatus with _$TaskStatus {
  const factory TaskStatus({
    @JsonKey(fromJson: _taskStatusIdToString) required String id,
    required String status,
    String? bookId,
    String? error,
    @JsonKey(name: 'progress') double? progress,
    @JsonKey(name: 'current_step') String? currentStep,
  }) = _TaskStatus;

  factory TaskStatus.fromJson(Map<String, dynamic> json) =>
      _$TaskStatusFromJson(json);
}

/// Расширение для TaskStatus с поддержкой BookGenerationStep
extension TaskStatusExtension on TaskStatus {
  /// Получить текущий этап генерации как enum
  /// Всегда возвращает валидный enum, fallback на text если неизвестен
  BookGenerationStep get generationStep {
    if (currentStep == null) {
      // Fallback: определяем по status
      if (status == 'completed' || status == 'done') {
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
    return BookGenerationStep.fromString(currentStep) ?? BookGenerationStep.text;
  }

  /// Получить статус генерации
  BookGenerationStatus get generationStatus {
    final step = generationStep; // Теперь всегда валидный enum
    final message = currentStep ?? status;
    return BookGenerationStatus(
      step: step,
      message: message,
      progress: progress,
    );
  }
}

