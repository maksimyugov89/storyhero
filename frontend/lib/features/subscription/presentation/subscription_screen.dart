import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/presentation/layouts/app_page.dart';
import '../../../core/presentation/design_system/app_colors.dart';
import '../../../core/presentation/design_system/app_typography.dart';
import '../../../core/presentation/design_system/app_spacing.dart';
import '../../../core/utils/text_style_helpers.dart';
import '../../../core/presentation/widgets/cards/app_magic_card.dart';
import '../../../core/presentation/widgets/buttons/app_magic_button.dart';
import '../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../ui/components/asset_icon.dart';
import '../../../core/models/book_style.dart';
import '../data/subscription_provider.dart';
import '../../../ui/layouts/desktop_container.dart';

class SubscriptionScreen extends HookConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionState = ref.watch(subscriptionProvider);
    final isProcessing = useState(false);
    final error = useState<String?>(null);

    Future<void> handleSubscribe() async {
      isProcessing.value = true;
      error.value = null;

      try {
        final success = await ref.read(subscriptionProvider.notifier).subscribe();
        
        if (success && context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Подписка оформлена!'),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎉 Поздравляем!',
                    style: AppTypography.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Теперь вам доступны все ${premiumStyles.length} премиум стилей для создания книг!',
                    style: AppTypography.bodyMedium,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.pop();
                  },
                  child: const Text('Отлично!'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        error.value = e.toString();
      } finally {
        isProcessing.value = false;
      }
    }

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_main.png',
      overlayOpacity: 0.2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: 'Подписка',
          leading: IconButton(
            icon: AssetIcon(
              assetPath: AppIcons.back,
              size: 24,
              color: AppColors.onBackground,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        body: DesktopContainer(
          maxWidth: 900,
          child: SingleChildScrollView(
            padding: AppSpacing.paddingMD,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  children: [
              const SizedBox(height: AppSpacing.lg),

              // Заголовок
              _buildHeader(context, subscriptionState.isSubscribed),

              const SizedBox(height: AppSpacing.xl),

              // Преимущества подписки
              _buildBenefits(context),

              const SizedBox(height: AppSpacing.xl),

              // Карточка с ценой
              if (!subscriptionState.isSubscribed) ...[
                _buildPriceCard(context),
                
                const SizedBox(height: AppSpacing.lg),

                // Ошибка
                if (error.value != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: AppSpacing.paddingSM,
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error.value!,
                            style: safeCopyWith(
                              AppTypography.bodySmall,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Кнопка подписки
                AppMagicButton(
                  onPressed: isProcessing.value ? null : handleSubscribe,
                  isLoading: isProcessing.value,
                  fullWidth: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Оформить подписку за 199 ₽',
                        style: safeCopyWith(
                          AppTypography.labelLarge,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                Text(
                  'Подписка на 30 дней • Автопродление отключено',
                  style: safeCopyWith(
                    AppTypography.bodySmall,
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                // Если уже подписан
                _buildActiveSubscription(context, subscriptionState),
              ],

              const SizedBox(height: AppSpacing.xl),

              // Превью стилей
              _buildStylesPreview(context, subscriptionState.isSubscribed),

                  const SizedBox(height: AppSpacing.xxl),
                ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isSubscribed) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSubscribed
                  ? [Colors.green.shade400, Colors.green.shade600]
                  : [Colors.amber.shade400, Colors.orange.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isSubscribed ? Colors.green : Colors.amber).withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            isSubscribed ? Icons.verified : Icons.workspace_premium,
            size: 50,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          isSubscribed ? 'Подписка активна!' : 'StoryHero Premium',
          style: AppTypography.headlineLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          isSubscribed
              ? 'Вам доступны все премиум стили'
              : 'Откройте все стили для создания книг',
          style: safeCopyWith(
            AppTypography.bodyLarge,
            color: AppColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBenefits(BuildContext context) {
    final benefits = [
      {'icon': Icons.palette, 'text': '${premiumStyles.length} премиум стилей'},
      {'icon': Icons.auto_awesome, 'text': 'Disney, Pixar, Гибли и другие'},
      {'icon': Icons.brush, 'text': 'Живопись, акварель, цифровой арт'},
      {'icon': Icons.all_inclusive, 'text': 'Неограниченные генерации'},
    ];

    return AppMagicCard(
      padding: AppSpacing.paddingLG,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text(
                'Что входит в подписку',
                style: safeCopyWith(
                  AppTypography.headlineSmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...benefits.map((b) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    b['icon'] as IconData,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                  b['text'] as String,
                  style: AppTypography.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildPriceCard(BuildContext context) {
    return AppMagicCard(
      padding: AppSpacing.paddingLG,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '199',
                style: safeCopyWith(
                  AppTypography.displayLarge,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  ' ₽',
                  style: safeCopyWith(
                    AppTypography.headlineMedium,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'в месяц',
            style: safeCopyWith(
              AppTypography.bodyLarge,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '💰 Экономия более 80%',
              style: safeCopyWith(
                AppTypography.labelMedium,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSubscription(BuildContext context, SubscriptionState state) {
    return AppMagicCard(
      padding: AppSpacing.paddingLG,
      child: Column(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Подписка активна',
            style: safeCopyWith(
              AppTypography.headlineMedium,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          if (state.expiresAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Действует до: ${_formatDate(state.expiresAt!)}',
              style: safeCopyWith(
                AppTypography.bodyMedium,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStylesPreview(BuildContext context, bool isSubscribed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Премиум стили',
          style: safeCopyWith(
            AppTypography.headlineMedium,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: premiumStyles.take(10).map((style) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSubscribed
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSubscribed
                    ? AppColors.primary.withOpacity(0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isSubscribed)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.lock, size: 14, color: AppColors.onBackground),
                  ),
                Flexible(
                  child: Text(
                  style.name,
                  style: safeCopyWith(
                    AppTypography.labelSmall,
                      color: AppColors.onBackground,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )).toList(),
        ),
        if (premiumStyles.length > 10) ...[
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: () => _showAllStylesDialog(context, isSubscribed),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'и ещё ${premiumStyles.length - 10} стилей...',
                    style: safeCopyWith(
                      AppTypography.bodyMedium,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showAllStylesDialog(BuildContext context, bool isSubscribed) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.palette, color: AppColors.primary, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Все премиум стили',
                style: safeCopyWith(
                  AppTypography.headlineSmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Доступно ${premiumStyles.length} премиум стилей:',
                style: safeCopyWith(
                  AppTypography.bodyMedium,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: premiumStyles.map((style) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSubscribed
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSubscribed
                          ? AppColors.primary.withOpacity(0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isSubscribed)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.lock, size: 14, color: AppColors.onBackground),
                        ),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              style.name,
                              style: safeCopyWith(
                                AppTypography.labelMedium,
                                color: AppColors.onBackground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (style.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                style.description,
                                style: safeCopyWith(
                                  AppTypography.bodySmall,
                                  color: AppColors.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

