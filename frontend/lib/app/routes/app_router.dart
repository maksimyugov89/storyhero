import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/auth/auth_status.dart';
import '../../core/auth/auth_status_provider.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/children/presentation/children_list_screen.dart';
import '../../features/children/presentation/child_create_screen.dart';
import '../../features/children/presentation/child_edit_screen.dart';
import '../../features/children/presentation/child_profile_screen.dart';
import '../../features/books/presentation/books_list_screen.dart';
import '../../features/books/presentation/book_view_screen.dart';
import '../../features/books/presentation/child_books_screen.dart';
import '../../features/books/presentation/edit_scene_screen.dart';
import '../../features/books/presentation/edit_text_screen.dart';
import '../../features/books/presentation/finalization_screen.dart';
import '../../features/generate/presentation/create_book_screen.dart';
import '../../features/generate/presentation/task_status_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/payments/presentation/payment_screen.dart';
import '../../core/models/child.dart';
import 'route_names.dart';

/// ChangeNotifier для обновления GoRouter при изменении authStatus
class GoRouterAuthRefresh extends ChangeNotifier {
  GoRouterAuthRefresh(this.ref) {
    ref.listen<AuthStatus>(
      authStatusProvider,
      (previous, next) {
        if (previous != next) {
          notifyListeners();
        }
      },
    );
  }

  final Ref ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = GoRouterAuthRefresh(ref);

  return GoRouter(
    initialLocation: RouteNames.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final auth = ref.read(authStatusProvider);
      final isAuthRoute = state.uri.path.startsWith('/auth');

      if (auth == AuthStatus.unknown) return null;

      if (auth == AuthStatus.unauthenticated) {
        return isAuthRoute ? null : RouteNames.login;
      }

      if (auth == AuthStatus.authenticated) {
        return isAuthRoute ? RouteNames.home : null;
      }

      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Страница не найдена')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Маршрут не найден: ${state.uri.path}',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(RouteNames.home),
              child: const Text('На главную'),
            ),
          ],
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: RouteNames.home,
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: RouteNames.books,
        builder: (_, __) => const BooksListScreen(),
      ),
      GoRoute(
        path: RouteNames.children,
        builder: (_, __) => const ChildrenListScreen(),
      ),
      GoRoute(
        path: RouteNames.childrenNew,
        builder: (_, __) => const ChildCreateScreen(),
      ),
      GoRoute(
        path: RouteNames.childProfile,
        builder: (context, state) {
          final childId = state.pathParameters['id']!;
          return ChildProfileScreen(childId: childId);
        },
      ),
      GoRoute(
        path: RouteNames.childEdit,
        builder: (context, state) {
          final childId = state.pathParameters['id'];
          final child = state.extra as Child?;
          
          // Если child передан через extra, используем его
          if (child != null) {
            return ChildEditScreen(child: child);
          }
          
          // Если childId есть, но child не передан, показываем ошибку
          if (childId == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Ошибка')),
              body: const Center(child: Text('ID ребёнка не указан')),
              floatingActionButton: FloatingActionButton(
                onPressed: () => context.go(RouteNames.home),
                child: const Icon(Icons.home),
              ),
            );
          }
          
          // Fallback: пытаемся получить child из провайдера
          return Scaffold(
            appBar: AppBar(title: const Text('Загрузка...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        },
      ),
      GoRoute(
        path: RouteNames.childBooks,
        builder: (context, state) {
          final childId = state.pathParameters['id'];
          if (childId == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Ошибка')),
              body: const Center(child: Text('ID ребёнка не указан')),
              floatingActionButton: FloatingActionButton(
                onPressed: () => context.go(RouteNames.home),
                child: const Icon(Icons.home),
              ),
            );
          }
          return ChildBooksScreen(childId: childId);
        },
      ),
      GoRoute(
        path: RouteNames.bookView,
        builder: (context, state) {
          final bookId = state.pathParameters['id']!;
          return BookViewScreen(bookId: bookId);
        },
      ),
      GoRoute(
        path: RouteNames.bookSceneEdit,
        builder: (context, state) {
          final bookId = state.pathParameters['id']!;
          final sceneIndex = int.parse(state.pathParameters['index']!);
          return EditSceneScreen(bookId: bookId, sceneIndex: sceneIndex);
        },
      ),
      GoRoute(
        path: RouteNames.bookTextEdit,
        builder: (context, state) {
          final bookId = state.pathParameters['id']!;
          final sceneIndex = int.parse(state.pathParameters['index']!);
          return EditTextScreen(bookId: bookId, sceneIndex: sceneIndex);
        },
      ),
      GoRoute(
        path: RouteNames.bookFinalize,
        builder: (context, state) {
          final bookId = state.pathParameters['id']!;
          return FinalizationScreen(bookId: bookId);
        },
      ),
      GoRoute(
        path: RouteNames.generate,
        builder: (_, __) => const CreateBookScreen(),
      ),
      GoRoute(
        path: RouteNames.taskStatus,
        builder: (context, state) {
          final taskId = state.pathParameters['id']!;
          return TaskStatusScreen(taskId: taskId);
        },
      ),
      GoRoute(
        path: RouteNames.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: RouteNames.payment,
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          return PaymentScreen(bookId: bookId);
        },
      ),
    ],
  );
});
