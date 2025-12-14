import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../app/routes/app_router.dart';
import '../../../app/routes/route_names.dart';
import '../../../core/auth/auth_status_provider.dart';
import '../../../core/auth/auth_status.dart';

class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> {
  bool _hasNavigated = false;
  bool _timeoutSet = false;

  @override
  void initState() {
    super.initState();
    // Устанавливаем таймаут на случай, если провайдер зависнет
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_timeoutSet) {
        _timeoutSet = true;
        Future.delayed(const Duration(seconds: 3), () {
          if (!_hasNavigated && mounted) {
            print('[LoadingScreen] Таймаут ожидания (6 сек), переходим на ${RouteNames.login}');
            _navigateToRoute(RouteNames.login);
          }
        });
      }
    });
  }

  void _navigateToRoute(String route) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    
    print('[LoadingScreen] Навигация на: $route');
    
    // Используем небольшую задержку для плавной навигации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _hasNavigated) {
          try {
            context.go(route);
            print('[LoadingScreen] ✅ Навигация выполнена: $route');
          } catch (e) {
            print('[LoadingScreen] ❌ Ошибка навигации: $e');
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Используем ref.watch для отслеживания изменений состояния
    // Это гарантирует, что виджет перестроится при изменении провайдера
    final authStatus = ref.watch(authStatusProvider);

    // Реагируем на изменения состояния авторизации
    if (authStatus != AuthStatus.unknown && !_hasNavigated && mounted) {
      print('[LoadingScreen] Состояние авторизации получено: $authStatus');
      if (authStatus == AuthStatus.authenticated) {
        _navigateToRoute(RouteNames.home);
      } else {
        _navigateToRoute(RouteNames.login);
      }
    }
    
    // RepaintBoundary изолирует перерисовки этого виджета
    // Это критически важно для предотвращения бесконечных перерисовок
    return RepaintBoundary(
      child: Scaffold(
      backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Фоновое изображение (нижний слой)
            Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Вычисляем оптимальный размер, чтобы изображение поместилось целиком
            final imageWidth = constraints.maxWidth;
            final imageHeight = constraints.maxHeight;
            
            return Image.asset(
              'assets/logo/storyhero_start.png',
              fit: BoxFit.contain,
              width: imageWidth,
              height: imageHeight,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                );
              },
            );
          },
              ),
            ),
            // Lottie анимация (верхний слой) - внизу экрана
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: 0.85,
                child: Center(
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: Lottie.asset(
                      'assets/animations/login_magic_swirl.json',
                      repeat: true,
                      errorBuilder: (context, error, stackTrace) {
                        // Если анимация не загрузилась, возвращаем пустой виджет
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

