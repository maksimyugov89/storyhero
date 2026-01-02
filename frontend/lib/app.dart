import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'core/presentation/design_system/app_theme.dart';
import 'app/routes/app_router.dart';
import 'core/services/deep_link_service.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  final DeepLinkService _deepLinkService = DeepLinkService();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Инициализируем обработку deep links только один раз в initState
      WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_initialized) {
        _initializeDeepLinkHandling();
      }
      });
  }

  void _initializeDeepLinkHandling() async {
    if (_initialized) return; // Защита от повторной инициализации
    _initialized = true;
    
    try {
      // Инициализируем deep link service (router будет получен через ref)
      final router = ref.read(routerProvider);
      await _deepLinkService.initialize(router);
      
      print('[App] Deep link handling initialized');
    } catch (e) {
      print('[App] Error initializing deep link handling: $e');
      _initialized = false; // Разрешаем повторную попытку при ошибке
    }
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      title: 'StoryHero',
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

