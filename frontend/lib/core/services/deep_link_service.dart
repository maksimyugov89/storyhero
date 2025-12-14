import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:app_links/app_links.dart';

/// Сервис для обработки deep links
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  StreamSubscription<Uri>? _linkSubscription;
  final AppLinks _appLinks = AppLinks();
  GoRouter? _router;

  /// Инициализирует обработку deep links
  Future<void> initialize(GoRouter router) async {
    try {
      _router = router;
      
      print('[DeepLinkService] Initializing deep link service...');
      
      // Обработка deep link, когда приложение уже запущено
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (Uri uri) {
          print('[DeepLinkService] Received deep link while app is running: $uri');
          _handleDeepLink(uri.toString());
        },
        onError: (err) {
          print('[DeepLinkService] Error listening to deep links: $err');
        },
      );
      
      // Обработка deep link, когда приложение открывается через deep link
      try {
        final initialLink = await _appLinks.getInitialLink();
        if (initialLink != null) {
          print('[DeepLinkService] Received initial deep link: $initialLink');
          // Ждем немного, чтобы приложение полностью загрузилось
          Future.delayed(const Duration(milliseconds: 1000), () {
            _handleDeepLink(initialLink.toString());
          });
        }
      } catch (e) {
        print('[DeepLinkService] Error getting initial link: $e');
      }
      
      print('[DeepLinkService] Deep link service initialized successfully');
    } catch (e) {
      print('[DeepLinkService] Error initializing: $e');
    }
  }
  
  /// Обрабатывает deep link URL
  Future<void> _handleDeepLink(String url) async {
    try {
      print('[DeepLinkService] ========== DEEP LINK RECEIVED ==========');
      print('[DeepLinkService] Full URL: $url');
      
      final uri = Uri.parse(url);
      
      // Обработка различных типов deep links
      if (uri.scheme == 'storyhero' || uri.scheme == 'https') {
        // Можно добавить обработку специфичных deep links в будущем
        print('[DeepLinkService] Processing deep link: ${uri.path}');
        
        // Пример: storyhero://books/123 -> /books/123
        if (uri.path.isNotEmpty && _router != null) {
          final path = uri.path;
          print('[DeepLinkService] Navigating to: $path');
          _router?.go(path);
        }
      }
      
      print('[DeepLinkService] ========== DEEP LINK PROCESSING COMPLETE ==========');
    } catch (e, stackTrace) {
      print('[DeepLinkService] Error handling deep link: $e');
      print('[DeepLinkService] Stack trace: $stackTrace');
    }
  }
  
  /// Очистка ресурсов
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}
