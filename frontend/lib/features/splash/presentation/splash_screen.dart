import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:lottie/lottie.dart';
import '../../../core/presentation/layouts/app_page.dart';
import '../../../core/presentation/design_system/app_colors.dart';
import '../../../core/presentation/design_system/app_typography.dart';
import '../../../core/presentation/design_system/app_spacing.dart';
import '../../../features/auth/data/auth_repository.dart';
import '../../../core/auth/auth_status.dart';
import '../../../core/auth/auth_status_provider.dart';
import '../../../app/routes/route_names.dart';

/// Splash экран с логотипом и проверкой авторизации
class SplashScreen extends HookConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fadeController = useAnimationController(
      duration: const Duration(milliseconds: 1000),
    );
    final navigated = useRef<bool>(false);
    
    // Слушаем изменения authStatus и навигируем
    ref.listen<AuthStatus>(authStatusProvider, (previous, next) {
      // Навигируем только если состояние изменилось с unknown на определенное
      // или если это первое значение и оно уже определено
      if (next != AuthStatus.unknown && !navigated.value) {
        navigated.value = true;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!context.mounted) return;
          
          if (next == AuthStatus.authenticated) {
            context.go(RouteNames.home);
          } else {
            context.go(RouteNames.login);
          }
        });
      }
    });
    
    // Проверяем начальное состояние (если уже определено, навигируем сразу)
    final authStatus = ref.watch(authStatusProvider);
    useEffect(() {
      if (authStatus != AuthStatus.unknown && !navigated.value) {
        navigated.value = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!context.mounted) return;
          
          if (authStatus == AuthStatus.authenticated) {
            context.go(RouteNames.home);
          } else {
            context.go(RouteNames.login);
          }
        });
      }
      return null;
    }, [authStatus]);

    final authRepo = ref.read(authRepositoryProvider);
    final authStatusNotifier = ref.read(authStatusProvider.notifier);
    
    useEffect(() {
      fadeController.forward();
      
      // Проверяем токен при старте и обновляем authStatusProvider
      Future.delayed(const Duration(seconds: 2), () async {
        if (!context.mounted || navigated.value) return;
        final token = await authRepo.token();
        
        if (!context.mounted || navigated.value) return;
        
        // Обновляем состояние авторизации
        // AuthRepository._checkAuthState() уже вызывается при инициализации,
        // но для надежности проверяем еще раз
        if (token != null && token.isNotEmpty) {
          authStatusNotifier.state = AuthStatus.authenticated;
        } else {
          authStatusNotifier.state = AuthStatus.unauthenticated;
        }
      });
      
      return null;
    }, [authRepo, authStatusNotifier]);

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_start.png',
      overlayOpacity: 0.2,
      safeArea: false,
      child: Stack(
        children: [
          // Центральный контент
          Center(
            child: FadeTransition(
              opacity: fadeController,
              child: Text(
                'Создаём магию...',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.onBackground,
                ),
              ),
            ),
          ),
          
          // Lottie анимация в нижней трети экрана
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: MediaQuery.of(context).size.height / 3,
              child: Center(
                child: Lottie.asset(
                  'assets/animations/login_magic_swirl.json',
                  fit: BoxFit.contain,
                  repeat: true,
                  animate: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

