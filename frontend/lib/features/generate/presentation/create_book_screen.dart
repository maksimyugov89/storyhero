import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/backend_api.dart';
import '../../../../core/models/child.dart';
import '../../../../core/models/book_style.dart';
import '../../../../core/presentation/layouts/app_page.dart';
import '../../../../core/presentation/design_system/app_colors.dart';
import '../../../../core/presentation/design_system/app_typography.dart';
import '../../../../core/presentation/design_system/app_spacing.dart';
import '../../../../core/utils/text_style_helpers.dart';
import '../../../../core/presentation/widgets/cards/app_magic_card.dart';
import '../../../../core/presentation/widgets/buttons/app_magic_button.dart';
import '../../../../core/presentation/widgets/buttons/app_button.dart';
import '../../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../../core/widgets/rounded_image.dart';
import '../../../../ui/components/asset_icon.dart';
import '../../auth/data/auth_repository.dart';
import '../../subscription/data/subscription_provider.dart';
import '../../../../app/routes/route_names.dart';

final childrenProvider = FutureProvider<List<Child>>((ref) async {
  final api = ref.watch(backendApiProvider);
  return await api.getChildren();
});

final selectedChildProvider = StateProvider<Child?>((ref) => null);
final selectedStyleProvider = StateProvider<String?>((ref) => null);
final selectedPagesProvider = StateProvider<int>((ref) => 20); // 10 или 20 страниц
final generationLockProvider = StateProvider<bool>((ref) => false);

class CreateBookScreen extends HookConsumerWidget {
  const CreateBookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = useState(1);
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    
    final childrenAsync = ref.watch(childrenProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final selectedStyle = ref.watch(selectedStyleProvider);

    Future<void> handleCreate() async {
      final isGenerationLocked = ref.read(generationLockProvider);
      if (isGenerationLocked) {
        errorMessage.value = 'Генерация уже запущена. Дождитесь завершения.';
        return;
      }

      final authRepo = ref.read(authRepositoryProvider);
      final user = await authRepo.currentUser();
      final token = await authRepo.token();
      
      if (user == null || token == null) {
        errorMessage.value = 'Для создания книги необходимо войти в аккаунт.';
        if (context.mounted) {
          Future.delayed(const Duration(seconds: 2), () {
            if (context.mounted) {
              context.go(RouteNames.login);
            }
          });
        }
        return;
      }

      if (selectedChild == null || selectedStyle == null) {
        errorMessage.value = 'Выберите ребёнка и стиль';
        return;
      }

      if (context.mounted) {
        isLoading.value = true;
        errorMessage.value = null;
        
        // Schedule provider update after build completes
        Future.microtask(() {
          ref.read(generationLockProvider.notifier).state = true;
        });
        
        try {
          final api = ref.read(backendApiProvider);
          final numPages = ref.read(selectedPagesProvider);
          final response = await api.generateFullBook(
            childId: selectedChild.id,
            style: selectedStyle,
            numPages: numPages,
          );

          if (context.mounted) {
            // Navigate after async operation completes
            Future.microtask(() {
              if (context.mounted) {
                context.go(RouteNames.taskStatus.replaceAll(':id', response.taskId));
              }
            });
          }
        } catch (e, stackTrace) {
          // Schedule provider update after build completes
          Future.microtask(() {
            ref.read(generationLockProvider.notifier).state = false;
          });
          
          // Детализированное логирование ошибки
          print('[CreateBookScreen] ❌ ОШИБКА при создании книги:');
          print('[CreateBookScreen] Тип ошибки: ${e.runtimeType}');
          print('[CreateBookScreen] Сообщение: $e');
          print('[CreateBookScreen] Stack trace: $stackTrace');
          
          final errorStr = e.toString();
          String userMessage;
          
          if (errorStr.contains('404') || errorStr.contains('не найден')) {
            userMessage = 'Ребёнок не найден. Проверьте выбранного ребёнка.';
            print('[CreateBookScreen] Ошибка 404: Ребёнок не найден');
          } else if (errorStr.contains('авторизация') || errorStr.contains('401') || errorStr.contains('403')) {
            userMessage = 'Ошибка авторизации. Пожалуйста, войдите в аккаунт.';
            print('[CreateBookScreen] Ошибка авторизации: 401/403');
            if (context.mounted) {
              Future.delayed(const Duration(seconds: 2), () {
                if (context.mounted) {
                  context.go(RouteNames.login);
                }
              });
            }
          } else if (errorStr.contains('500') || errorStr.contains('Internal Server Error')) {
            userMessage = 'Ошибка сервера. Попробуйте позже или обратитесь в поддержку.';
            print('[CreateBookScreen] Ошибка сервера: 500');
          } else if (errorStr.contains('timeout') || errorStr.contains('Timeout')) {
            userMessage = 'Превышено время ожидания. Проверьте подключение к интернету.';
            print('[CreateBookScreen] Ошибка таймаута');
          } else if (errorStr.contains('network') || errorStr.contains('Network')) {
            userMessage = 'Ошибка сети. Проверьте подключение к интернету.';
            print('[CreateBookScreen] Ошибка сети');
          } else {
            userMessage = 'Ошибка генерации: ${errorStr.length > 100 ? errorStr.substring(0, 100) + "..." : errorStr}';
            print('[CreateBookScreen] Неизвестная ошибка: $errorStr');
          }
          
          errorMessage.value = userMessage;
          isLoading.value = false;
        }
      }
    }

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_generate_book.png',
      overlayOpacity: 0.2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: 'Создать книгу ${currentStep.value}/3',
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
        body: Column(
          children: [
            // Прогресс-бар
            Padding(
              padding: AppSpacing.paddingMD,
              child: Row(
                children:                   List.generate(3, (index) {
                    final step = index + 1;
                    final isActive = step <= currentStep.value;
                  
                  return Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        if (step < 3) const SizedBox(width: 8),
                      ],
                    ),
                  );
                }),
              ),
            ),
            
            // Контент шага
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.paddingMD,
                child: _buildStepContent(
                  context,
                  ref,
                  currentStep.value,
                  childrenAsync,
                  selectedChild,
                  selectedStyle,
                  errorMessage.value,
                ),
              ),
            ),
            
            // Навигация
            Padding(
              padding: AppSpacing.paddingMD,
              child: Row(
                children: [
                  if (currentStep.value > 1)
                    Expanded(
                      child: AppButton(
                        text: 'Назад',
                        outlined: true,
                        onPressed: () {
                          currentStep.value--;
                          errorMessage.value = null;
                        },
                      ),
                    ),
                  if (currentStep.value > 1) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: currentStep.value < 3
                        ? AppMagicButton(
                            onPressed: () {
                              if (currentStep.value == 1 && selectedChild == null) {
                                errorMessage.value = 'Выберите ребёнка';
                                return;
                              }
                              if (currentStep.value == 2 && selectedStyle == null) {
                                errorMessage.value = 'Выберите стиль';
                                return;
                              }
                              currentStep.value++;
                              errorMessage.value = null;
                            },
                            fullWidth: true,
                            child: Text(
                              'Далее',
                              style: safeCopyWith(
                                AppTypography.labelLarge,
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : AppMagicButton(
                            onPressed: isLoading.value ? null : handleCreate,
                            isLoading: isLoading.value,
                            fullWidth: true,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AssetIcon(
                                  assetPath: AppIcons.magicPortal,
                                  size: 20,
                                  color: AppColors.onPrimary,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Flexible(
                                  child: Text(
                                  'Создать книгу',
                                    style: safeCopyWith(
                                      AppTypography.labelLarge,
                                    color: AppColors.onPrimary,
                                    fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(
    BuildContext context,
    WidgetRef ref,
    int step,
    AsyncValue<List<Child>> childrenAsync,
    Child? selectedChild,
    String? selectedStyle,
    String? errorMessage,
  ) {
    switch (step) {
      case 1:
        return _buildStep1(context, ref, childrenAsync, selectedChild, errorMessage);
      case 2:
        return _buildStep2(context, ref, selectedStyle, errorMessage);
      case 3:
        return _buildStep3(context, ref, selectedChild, selectedStyle, errorMessage);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Child>> childrenAsync,
    Child? selectedChild,
    String? errorMessage,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Выберите ребёнка',
          style: AppTypography.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Для кого создаём книгу?',
          style: safeCopyWith(
            AppTypography.bodyLarge,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        
        if (errorMessage != null) ...[
          Container(
            padding: AppSpacing.paddingMD,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error),
            ),
            child: Row(
              children: [
                AssetIcon(
                  assetPath: AppIcons.alert,
                  size: 20,
                  color: AppColors.error,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: safeCopyWith(
                      AppTypography.bodyMedium,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        
        childrenAsync.when(
          data: (children) {
            if (children.isEmpty) {
              return Column(
                children: [
                  AppMagicCard(
                    padding: AppSpacing.paddingLG,
                    child: Column(
                      children: [
                        AssetIcon(
                          assetPath: AppIcons.childProfile,
                          size: 64,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Нет анкет детей',
                          style: AppTypography.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Создайте анкету ребёнка для генерации книги',
                          style: safeCopyWith(
                            AppTypography.bodyMedium,
                            color: AppColors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await context.push(RouteNames.childrenNew);
                            // После возврата обновляем список детей
                            ref.invalidate(childrenProvider);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Создать анкету'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(childrenProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Обновить список'),
                  ),
                ],
              );
            }
            
            return Column(
              children: [
                // Список детей
                ...children.map((child) {
                  final isSelected = selectedChild?.id == child.id;
                  return Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppMagicCard(
                      onTap: () {
                        ref.read(selectedChildProvider.notifier).state = child;
                      },
                      selected: isSelected,
                      padding: AppSpacing.paddingMD,
                      child: Row(
                        children: [
                          if (child.faceUrl != null && child.faceUrl!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: RoundedImage(
                                imageUrl: child.faceUrl,
                                width: 60,
                                height: 60,
                                radius: 12,
                              ),
                            )
                          else
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  child.name[0].toUpperCase(),
                                  style: safeCopyWith(
                                    AppTypography.headlineSmall,
                                    color: AppColors.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  child.name,
                                  style: AppTypography.headlineSmall,
                                ),
                                Text(
                                  '${child.age} лет',
                                  style: safeCopyWith(
                                    AppTypography.bodyMedium,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            AssetIcon(
                              assetPath: AppIcons.success,
                              size: 24,
                              color: AppColors.success,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                // Кнопка добавления новой анкеты
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () async {
                    await context.push(RouteNames.childrenNew);
                    ref.invalidate(childrenProvider);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить анкету'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Container(
            padding: AppSpacing.paddingMD,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Ошибка загрузки: $error',
              style: safeCopyWith(
                AppTypography.bodyMedium,
                color: AppColors.error,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(
    BuildContext context,
    WidgetRef ref,
    String? selectedStyle,
    String? errorMessage,
  ) {
    final isSubscribed = ref.watch(isSubscribedProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Выберите стиль',
          style: AppTypography.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'В каком стиле будет книга?',
          style: safeCopyWith(
            AppTypography.bodyLarge,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        
        // Выбор количества страниц
        _buildPagesSelector(context, ref),
        
        const SizedBox(height: AppSpacing.md),
        
        // Баннер подписки
        if (!isSubscribed)
          GestureDetector(
            onTap: () => context.push(RouteNames.subscription),
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: AppSpacing.paddingSM,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade400, Colors.orange.shade400],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Откройте ${premiumStyles.length} премиум стилей за 199 ₽/мес',
                      style: safeCopyWith(
                        AppTypography.labelMedium,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        
        if (errorMessage != null) ...[
          Container(
            padding: AppSpacing.paddingMD,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error),
            ),
            child: Text(
              errorMessage,
              style: safeCopyWith(
                AppTypography.bodyMedium,
                color: AppColors.error,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        
        SizedBox(
          height: 450,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.85,
            ),
            itemCount: allBookStyles.length,
            itemBuilder: (context, index) {
              final style = allBookStyles[index];
              final isSelected = selectedStyle == style.id;
              final isLocked = style.isPremium && !isSubscribed;
              
              return AppMagicCard(
                onTap: () {
                  if (isLocked) {
                    // Показать предложение подписки
                    _showSubscriptionPrompt(context);
                  } else {
                    ref.read(selectedStyleProvider.notifier).state = style.id;
                  }
                },
                selected: isSelected,
                padding: AppSpacing.paddingMD,
                child: Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AssetIcon(
                          assetPath: AppIcons.magicStyle,
                          size: 40,
                          color: isLocked
                              ? AppColors.onSurfaceVariant.withOpacity(0.5)
                              : isSelected
                                  ? AppColors.primary
                                  : AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          style.name,
                          style: safeCopyWith(
                            AppTypography.labelLarge,
                            fontWeight: FontWeight.bold,
                            color: isLocked ? AppColors.onSurfaceVariant.withOpacity(0.5) : null,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          style.description,
                          style: safeCopyWith(
                            AppTypography.bodySmall,
                            color: isLocked
                                ? AppColors.onSurfaceVariant.withOpacity(0.5)
                                : AppColors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    // Замок для премиум стилей
                    if (isLocked)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.lock, size: 16, color: Colors.white),
                        ),
                      ),
                    // Бейдж "Бесплатно"
                    if (!style.isPremium)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'FREE',
                            style: safeCopyWith(
                              AppTypography.labelSmall,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 9.0,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPagesSelector(BuildContext context, WidgetRef ref) {
    final selectedPages = ref.watch(selectedPagesProvider);
    
    return Container(
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_stories, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Количество страниц',
                style: safeCopyWith(
                  AppTypography.labelLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildPageOption(
                  context,
                  ref,
                  pages: 10,
                  isSelected: selectedPages == 10,
                  description: 'Короткая история',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPageOption(
                  context,
                  ref,
                  pages: 20,
                  isSelected: selectedPages == 20,
                  description: 'Полная история',
                  isRecommended: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageOption(
    BuildContext context,
    WidgetRef ref, {
    required int pages,
    required bool isSelected,
    required String description,
    bool isRecommended = false,
  }) {
    return GestureDetector(
      onTap: () {
        ref.read(selectedPagesProvider.notifier).state = pages;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Text(
                  '$pages',
                  style: safeCopyWith(
                    AppTypography.headlineLarge,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  'страниц',
                  style: safeCopyWith(
                    AppTypography.labelMedium,
                    color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: safeCopyWith(
                    AppTypography.bodySmall,
                    color: AppColors.onSurfaceVariant,
                    fontSize: 10.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            if (isRecommended)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '👍',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSubscriptionPrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: AppSpacing.paddingLG,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Icon(Icons.workspace_premium, size: 64, color: Colors.amber),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Премиум стиль',
              style: AppTypography.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Этот стиль доступен по подписке.\nОткройте ${premiumStyles.length} премиум стилей всего за 199 ₽/мес',
              style: safeCopyWith(
                AppTypography.bodyMedium,
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.push(RouteNames.subscription);
                },
                icon: Icon(Icons.star, color: Colors.white),
                label: Text(
                  'Оформить подписку',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Выбрать бесплатный стиль'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3(
    BuildContext context,
    WidgetRef ref,
    Child? selectedChild,
    String? selectedStyle,
    String? errorMessage,
  ) {
    final style = allBookStyles.firstWhere(
      (s) => s.id == selectedStyle,
      orElse: () => const BookStyle(id: '', name: 'Неизвестный', description: ''),
    );
    final styleName = style.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Подтвердите создание',
          style: AppTypography.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Проверьте выбранные параметры',
          style: safeCopyWith(
            AppTypography.bodyLarge,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        
        if (errorMessage != null) ...[
          Container(
            padding: AppSpacing.paddingMD,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error),
            ),
            child: Text(
              errorMessage,
              style: safeCopyWith(
                AppTypography.bodyMedium,
                color: AppColors.error,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        
        AppMagicCard(
          padding: AppSpacing.paddingLG,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AssetIcon(
                    assetPath: AppIcons.childProfile,
                    size: 24,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Ребёнок',
                    style: safeCopyWith(
                      AppTypography.labelLarge,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (selectedChild != null) ...[
                Row(
                  children: [
                    if (selectedChild.faceUrl != null && selectedChild.faceUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: RoundedImage(
                          imageUrl: selectedChild.faceUrl,
                          width: 40,
                          height: 40,
                          radius: 8,
                        ),
                      )
                    else
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            selectedChild.name[0].toUpperCase(),
                            style: safeCopyWith(
                              AppTypography.labelLarge,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      selectedChild.name,
                      style: AppTypography.headlineSmall,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  AssetIcon(
                    assetPath: AppIcons.magicStyle,
                    size: 24,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Стиль',
                    style: safeCopyWith(
                      AppTypography.labelLarge,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                styleName,
                style: AppTypography.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Icon(
                    Icons.auto_stories,
                    size: 24,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Страницы',
                    style: safeCopyWith(
                      AppTypography.labelLarge,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${ref.watch(selectedPagesProvider)} страниц',
                style: AppTypography.headlineSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
