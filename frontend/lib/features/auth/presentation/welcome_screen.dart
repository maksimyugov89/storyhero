import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes/route_names.dart';
import '../../../ui/components/glowing_capsule_button.dart';
import '../../../ui/components/asset_icon.dart';
import '../../../core/widgets/magic/glassmorphic_card.dart';

class WelcomeScreen extends HookConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fadeAnimation = useAnimationController(
      duration: const Duration(milliseconds: 800),
    );
    final scaleAnimation = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );

    useEffect(() {
      fadeAnimation.forward();
      scaleAnimation.forward();
      return null;
    }, []);

    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Фоновое изображение
          Positioned.fill(
            child: Image.asset(
              'assets/logo/storyhero_menyu.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1F1147),
                        const Color(0xFF4A1A7F),
                        const Color(0xFF9B5EFF),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                );
              },
            ),
          ),
          // Слегка затемняющий overlay
          Container(
            color: Colors.black.withOpacity(0.2),
          ),
          // Контент
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      // Логотип
                      FadeTransition(
                        opacity: fadeAnimation,
                        child: ScaleTransition(
                          scale: scaleAnimation,
                          child: Center(
                            child: Image.asset(
                              'assets/logo/storyhero_start.png',
                              width: size.width * 0.6,
                              height: size.width * 0.6,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.auto_stories,
                                  size: 120,
                                  color: Colors.white,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                      // Заголовок
                      FadeTransition(
                        opacity: fadeAnimation,
                        child: Text(
                          'StoryHero',
                          textAlign: TextAlign.center,
                          style: safeCopyWith(
                            Theme.of(context).textTheme.displayLarge,
                            fontSize: 48.0,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ).copyWith(
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeTransition(
                        opacity: fadeAnimation,
                        child: Text(
                          'Создавайте персонализированные детские книги с помощью магии ИИ',
                          textAlign: TextAlign.center,
                          style: safeCopyWith(
                            Theme.of(context).textTheme.titleMedium,
                            fontSize: 18.0,
                            color: Colors.white.withOpacity(0.9),
                          ).copyWith(
                            shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                        ),
                      ),
                      const SizedBox(height: 60),
                      // Кнопки
                      FadeTransition(
                        opacity: fadeAnimation,
                        child: GlassmorphicCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GlowingCapsuleButton(
                                text: 'Войти',
                                icon: Icons.login,
                                onPressed: () => context.go(RouteNames.login),
                                width: double.infinity,
                                height: 56,
                              ),
                              const SizedBox(height: 16),
                              GlowingCapsuleButton(
                                text: 'Создать аккаунт',
                                iconAsset: AppIcons.profile,
                                onPressed: () => context.go(RouteNames.register),
                                width: double.infinity,
                                height: 56,
                              ),
                              const SizedBox(height: 24),
                              TextButton(
                                onPressed: () => context.go(RouteNames.login),
                                child: Text(
                                  'Продолжить',
                                  style: safeTextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

