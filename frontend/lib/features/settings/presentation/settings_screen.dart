import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../../subscription/data/subscription_provider.dart';
import '../../../core/presentation/layouts/app_page.dart';
import '../../../core/presentation/layouts/desktop_layout.dart';
import '../../../core/presentation/design_system/app_colors.dart';
import '../../../core/presentation/design_system/app_typography.dart';
import '../../../core/presentation/design_system/app_spacing.dart';
import '../../../core/utils/text_style_helpers.dart';
import '../../../core/presentation/widgets/cards/app_magic_card.dart';
import '../../../core/presentation/widgets/buttons/app_button.dart';
import '../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../ui/components/asset_icon.dart';
import '../../../app/routes/route_names.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../ui/layouts/desktop_container.dart';

final currentUserEmailProvider = FutureProvider<String?>((ref) async {
  final authRepo = ref.read(authRepositoryProvider);
  final user = await authRepo.currentUser();
  return user?.email;
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> handleSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final authRepo = ref.read(authRepositoryProvider);
        await authRepo.signOut();
        // authStatusProvider обновлен в AuthRepository
        // Router redirect автоматически перенаправит на /auth/login
        // НЕ вызываем context.go вручную
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка выхода: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailAsync = ref.watch(currentUserEmailProvider);

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_main.png',
      overlayOpacity: 0.2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: 'Настройки',
          leading: IconButton(
            icon: AssetIcon(
              assetPath: AppIcons.back,
              size: 24,
              color: AppColors.onBackground,
            ),
            onPressed: () {
              final router = GoRouter.of(context);
              if (router.canPop()) {
                context.pop();
              } else {
                context.go(RouteNames.home);
              }
            },
          ),
        ),
        body: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: child,
          ),
          child: kIsWeb
              ? DesktopLayout(
                  enableConstraints: true,
                  applyBackgroundOverlay: true,
                  child: DesktopContainer(
                    maxWidth: 900,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                        'Настройки',
                        style: safeCopyWith(
                          AppTypography.headlineLarge,
                          fontWeight: FontWeight.bold,
                          fontSize: 40,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Управление профилем, подпиской и приложением',
                        style: safeCopyWith(
                          AppTypography.bodyLarge,
                          color: AppColors.onSurfaceVariant,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Двухколоночный layout
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Левая колонка (Профиль + Подписка)
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                // Профиль
                                AppMagicCard(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          AssetIcon(
                                            assetPath: AppIcons.profile,
                                            size: 32,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 16),
                                          Text(
                                            'Профиль',
                                            style: safeCopyWith(
                                              AppTypography.headlineMedium,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 24,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      emailAsync.when(
                                        data: (email) {
                                          if (email == null) {
                                            return Text(
                                              'Не удалось загрузить email',
                                              style: safeCopyWith(
                                                AppTypography.bodyMedium,
                                                color: AppColors.onSurfaceVariant,
                                              ),
                                            );
                                          }
                                          return Row(
                                            children: [
                                              AssetIcon(
                                                assetPath: AppIcons.email,
                                                size: 24,
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Text(
                                                  email,
                                                  style: safeCopyWith(
                                                    AppTypography.headlineSmall,
                                                    fontSize: 20,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                        loading: () => const CircularProgressIndicator(),
                                        error: (_, __) => Text(
                                          'Ошибка загрузки email',
                                          style: safeCopyWith(
                                            AppTypography.bodyMedium,
                                            color: AppColors.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Подписка
                                _SubscriptionCard(),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 32),
                          
                          // Правая колонка (Приложение + Выход)
                          Expanded(
                            flex: 1,
                            child: Column(
                              children: [
                                // Приложение
                                AppMagicCard(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Приложение',
                                        style: safeCopyWith(
                                          AppTypography.headlineMedium,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      _SettingsItem(
                                        icon: AppIcons.help,
                                        title: 'Помощь и поддержка',
                                        subtitle: 'Связаться с разработчиком',
                                        onTap: () => context.push(RouteNames.help),
                                      ),
                                      const Divider(),
                                      _SettingsItem(
                                        icon: AppIcons.help,
                                        title: 'Версия приложения',
                                        subtitle: '1.0.0',
                                        onTap: null,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Кнопка выхода
                                Align(
                                  alignment: Alignment.center,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 460),
                                    child: AppButton(
                                      text: 'Выйти из аккаунта',
                                      icon: Icons.logout,
                                      outlined: false,
                                      fullWidth: true,
                                      onPressed: () => handleSignOut(context, ref),
                                      backgroundColor: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 80),
                    ],
                      ),
                    ),
                  ),
                )
              : DesktopContainer(
                  maxWidth: 900,
                  child: SingleChildScrollView(
                    padding: AppSpacing.paddingMD,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.lg),
                    
                    // Профиль
                    AppMagicCard(
                      padding: AppSpacing.paddingLG,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AssetIcon(
                                assetPath: AppIcons.profile,
                                size: 24,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Профиль',
                                style: AppTypography.headlineSmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          emailAsync.when(
                            data: (email) {
                              if (email == null) {
                                return Text(
                                  'Не удалось загрузить email',
                                  style: safeCopyWith(
                                    AppTypography.bodyMedium,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                );
                              }
                              return Row(
                                children: [
                                  AssetIcon(
                                    assetPath: AppIcons.email,
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      email,
                                      style: AppTypography.bodyLarge,
                                    ),
                                  ),
                                ],
                              );
                            },
                            loading: () => const CircularProgressIndicator(),
                            error: (_, __) => Text(
                              'Ошибка загрузки email',
                              style: safeCopyWith(
                                AppTypography.bodyMedium,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.lg),
                    
                    // Подписка
                    _SubscriptionCard(),
                    
                    const SizedBox(height: AppSpacing.lg),
                    
                    // Приложение
                    AppMagicCard(
                      padding: AppSpacing.paddingLG,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Приложение',
                            style: AppTypography.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _SettingsItem(
                            icon: AppIcons.help,
                            title: 'Помощь и поддержка',
                            subtitle: 'Связаться с разработчиком',
                            onTap: () => context.push(RouteNames.help),
                          ),
                          const Divider(),
                          _SettingsItem(
                            icon: AppIcons.help,
                            title: 'Версия приложения',
                            subtitle: '1.0.0',
                            onTap: null,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.xl),
                    
                    // Кнопка выхода
                    Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: AppButton(
                          text: 'Выйти из аккаунта',
                          icon: Icons.logout,
                          outlined: false,
                          fullWidth: true,
                          onPressed: () => handleSignOut(context, ref),
                          backgroundColor: AppColors.error,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final String icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            AssetIcon(
              assetPath: icon,
              size: 24,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle!,
                      style: safeCopyWith(
                        AppTypography.bodySmall,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: AppColors.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionState = ref.watch(subscriptionProvider);
    final isSubscribed = subscriptionState.isSubscribed;

    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSubscribed
                      ? [Colors.green.shade400, Colors.green.shade600]
                      : [Colors.amber.shade400, Colors.orange.shade600],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSubscribed ? Icons.verified : Icons.workspace_premium,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Подписка',
                    style: AppTypography.headlineSmall,
                  ),
                  Text(
                    isSubscribed
                        ? '✅ Активна — все стили доступны'
                        : '20 премиум стилей за 199 ₽/мес',
                    style: safeCopyWith(
                      AppTypography.bodySmall,
                      color: isSubscribed ? Colors.green : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.onSurfaceVariant,
            ),
          ],
        ),
        if (!isSubscribed) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade400, Colors.orange.shade400],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '⭐ Оформить подписку',
              style: safeCopyWith(
                AppTypography.labelMedium,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );

    return GestureDetector(
      onTap: () => context.push(RouteNames.subscription),
      child: kIsWeb
          ? GlassContainer(
              padding: const EdgeInsets.all(24),
              child: cardContent,
            )
          : AppMagicCard(
              padding: AppSpacing.paddingLG,
              child: cardContent,
            ),
    );
  }
}
