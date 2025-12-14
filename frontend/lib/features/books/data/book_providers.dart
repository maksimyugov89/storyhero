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
    return await api.getBook(bookId);
  } catch (e) {
    // Если getBook не работает, пробуем старый способ
    final books = await api.getBooks();
    try {
      return books.firstWhere((b) => b.id == bookId);
    } catch (_) {
      throw Exception('Книга с ID $bookId не найдена');
    }
  }
});

/// Провайдер для получения сцен книги
final bookScenesProvider = FutureProvider.family<List<Scene>, String>((ref, bookId) async {
  final api = ref.watch(backendApiProvider);
  return await api.getBookScenes(bookId);
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

