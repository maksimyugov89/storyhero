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
    final taskIdValue = json['task_id'] ?? json['taskId'] ?? json['id'];
    final taskId = _stringFromDynamic(taskIdValue);
    final message = (json['message'] as String?) ??
        (json['detail'] as String?) ??
        'Книга генерируется';

    dynamic childIdValue = json['child_id'] ??
        json['childId'] ??
        json['book_id'] ??
        json['bookId'];
    final meta = json['meta'];
    if (childIdValue == null && meta is Map) {
      childIdValue = meta['child_id'] ??
          meta['childId'] ??
          meta['book_id'] ??
          meta['bookId'];
    }
    final childId = _stringFromDynamic(childIdValue) ?? '';

    if (taskId == null || taskId.isEmpty) {
      throw const FormatException(
        'Некорректный ответ от сервера: отсутствует task_id',
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

String? _stringFromDynamic(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is num) return value.toString();
  return value.toString();
}
