/// Модель ответа от эндпоинта POST /books/generate_full_book
/// 
/// Backend возвращает:
/// {
///   "task_id": "03cbf305-4a8a-4a94-bbb0-5a08312ad567",
///   "message": "Книга генерируется",
///   "child_id": "e2e160ad-63d9-4007-84fe-e41be8e6cde0"
/// }
class GenerateFullBookResponse {
  final String taskId;
  final String childId;
  final String message;

  const GenerateFullBookResponse({
    required this.taskId,
    required this.childId,
    required this.message,
  });

  factory GenerateFullBookResponse.fromJson(Map<String, dynamic> json) {
    final taskId = json['task_id'] as String?;
    // child_id может быть int (PostgreSQL) или String (UUID)
    final childIdValue = json['child_id'];
    final childId = childIdValue is int 
        ? childIdValue.toString() 
        : childIdValue as String?;
    final message = (json['message'] as String?) ?? 'Книга генерируется';

    if (taskId == null || childId == null) {
      throw const FormatException(
        'Некорректный ответ от сервера: отсутствуют обязательные поля',
      );
    }

    return GenerateFullBookResponse(
      taskId: taskId,
      childId: childId,
      message: message,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'child_id': childId,
      'message': message,
    };
  }
}

