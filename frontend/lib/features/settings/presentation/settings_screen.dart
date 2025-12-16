import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/presentation/layouts/app_page.dart';
import '../../../core/presentation/design_system/app_colors.dart';
import '../../../core/presentation/design_system/app_typography.dart';
import '../../../core/presentation/design_system/app_spacing.dart';
import '../../../core/utils/text_style_helpers.dart';
import '../../../core/presentation/widgets/cards/app_magic_card.dart';
import '../../../core/presentation/widgets/buttons/app_button.dart';
import '../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../ui/components/asset_icon.dart';
import '../../../app/routes/route_names.dart';

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
        body: SingleChildScrollView(
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
                            Icon(
                              Icons.email,
                              color: AppColors.primary,
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
                      title: 'Помощь',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Помощь скоро будет доступна'),
                          ),
                        );
                      },
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
              AppButton(
                text: 'Выйти из аккаунта',
                icon: Icons.logout,
                outlined: false,
                fullWidth: true,
                onPressed: () => handleSignOut(context, ref),
                backgroundColor: AppColors.error,
              ),
              
              const SizedBox(height: AppSpacing.xl),
            ],
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
