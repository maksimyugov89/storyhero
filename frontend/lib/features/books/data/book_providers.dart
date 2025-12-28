import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/backend_api.dart';
import '../../../core/models/book.dart';
import '../../../core/models/scene.dart';

/// Провайдер для получения списка всех книг
final booksProvider = FutureProvider<List<Book>>((ref) async {
  final api = ref.watch(backendApiProvider);
  return await api.getBooks();
});

/// Провайдер для получения одной книги по ID
final bookProvider = FutureProvider.family<Book, String>((ref, bookId) async {
  final api = ref.watch(backendApiProvider);
  try {
    print('[bookProvider] Попытка получить книгу по ID: $bookId');
    final book = await api.getBook(bookId);
    print('[bookProvider] ✅ Книга успешно получена: ${book.title} (ID: ${book.id}, статус: ${book.status})');
    return book;
  } catch (e, stackTrace) {
    print('[bookProvider] ❌ Ошибка при получении книги по ID: $e');
    print('[bookProvider] Stack trace: $stackTrace');
    print('[bookProvider] Пробуем найти книгу в списке всех книг...');
    // Если getBook не работает (404), пробуем найти в списке всех книг
    try {
      final books = await api.getBooks();
      print('[bookProvider] Получен список из ${books.length} книг');
      print('[bookProvider] ID книг в списке: ${books.map((b) => b.id).join(", ")}');
      final foundBook = books.firstWhere(
        (b) => b.id == bookId,
        orElse: () => throw Exception('Книга с ID $bookId не найдена в списке'),
      );
      print('[bookProvider] ✅ Книга найдена в списке: ${foundBook.title} (ID: ${foundBook.id}, статус: ${foundBook.status})');
      return foundBook;
    } catch (listError) {
      print('[bookProvider] ❌ Книга не найдена в списке: $listError');
      throw Exception('Книга с ID $bookId не найдена. Возможно, она была удалена.');
    }
  }
});

/// Провайдер для получения сцен книги
final bookScenesProvider = FutureProvider.family<List<Scene>, String>((ref, bookId) async {
  final api = ref.watch(backendApiProvider);
  try {
    print('[bookScenesProvider] Запрос сцен для книги: $bookId');
    final scenes = await api.getBookScenes(bookId);
    print('[bookScenesProvider] ✅ Получено ${scenes.length} сцен для книги $bookId');
    if (scenes.isNotEmpty) {
      print('[bookScenesProvider] Первая сцена: order=${scenes.first.order}, id=${scenes.first.id}');
    } else {
      print('[bookScenesProvider] ⚠️ Список сцен пуст для книги $bookId');
    }
    return scenes;
  } catch (e, stackTrace) {
    print('[bookScenesProvider] ❌ Ошибка при получении сцен: $e');
    print('[bookScenesProvider] Stack trace: $stackTrace');
    rethrow;
  }
});

/// Провайдер для получения одной сцены
final sceneProvider = FutureProvider.family<Scene, ({String bookId, int sceneIndex})>((ref, params) async {
  final api = ref.watch(backendApiProvider);
  final scenes = await api.getBookScenes(params.bookId);
  try {
    final sortedScenes = [...scenes]..sort((a, b) => a.order.compareTo(b.order));
    return sortedScenes[params.sceneIndex];
  } catch (e) {
    throw Exception('Сцена не найдена');
  }
});

/// Провайдер для получения книг конкретного ребёнка
final childBooksProvider = FutureProvider.family<List<Book>, String>((ref, childId) async {
  final api = ref.watch(backendApiProvider);
  return await api.getBooksForChild(childId);
});

