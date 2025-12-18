import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes/route_names.dart';
import '../../../core/api/backend_api.dart';
import '../../../core/presentation/layouts/app_page.dart';
import '../../../core/presentation/design_system/app_colors.dart';
import '../../../core/presentation/design_system/app_typography.dart';
import '../../../core/presentation/design_system/app_spacing.dart';
import '../../../core/utils/text_style_helpers.dart';
import '../../../core/presentation/widgets/buttons/app_magic_button.dart';
import '../../../core/presentation/widgets/cards/app_magic_card.dart';
import '../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/rounded_image.dart';
import '../../../core/services/screenshot_protection_service.dart';
import '../../../ui/components/asset_icon.dart';
import '../data/book_providers.dart';
import '../data/scene_variants_provider.dart';

class BookFinalizeScreen extends HookConsumerWidget {
  final String bookId;

  const BookFinalizeScreen({
    super.key,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookProvider(bookId));
    final scenesAsync = ref.watch(bookScenesProvider(bookId));
    final variantsNotifier = ref.watch(sceneVariantsProvider.notifier);
    final variants = ref.watch(sceneVariantsProvider);
    
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final currentPage = useState(0);
    final pageController = usePageController();

    // Включаем защиту от скриншотов при входе на экран
    useEffect(() {
      ScreenshotProtectionService.enableProtection();
      return () {
        ScreenshotProtectionService.disableProtection();
      };
    }, []);

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_final_story.png',
      overlayOpacity: 0.3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: 'Финализация книги',
          leading: IconButton(
            icon: AssetIcon(
              assetPath: AppIcons.back,
              size: 24,
              color: AppColors.onBackground,
            ),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(RouteNames.home);
              }
            },
          ),
        ),
        body: bookAsync.when(
          data: (book) {
            return scenesAsync.when(
              data: (scenes) {
                if (scenes.isEmpty) {
                  return Center(
                    child: Text(
                      'Нет сцен для отображения',
                      style: safeCopyWith(
                        AppTypography.bodyLarge,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                Future<void> handleFinalize() async {
                  isLoading.value = true;
                  errorMessage.value = null;

                  try {
                    final api = ref.read(backendApiProvider);
                    await api.finalizeBook(bookId);

                    if (context.mounted) {
                      // Очищаем варианты
                      variantsNotifier.clearAll();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Книга отправлена на финальный рендеринг!'),
                          backgroundColor: AppColors.success,
                        ),
                      );

                      // Переходим на экран книги
                      context.go(RouteNames.bookView.replaceAll(':id', bookId));
                    }
                  } catch (e) {
                    errorMessage.value = 'Ошибка финализации: ${e.toString().replaceAll('Exception: ', '')}';
                  } finally {
                    isLoading.value = false;
                  }
                }

                return Column(
                  children: [
                    // Прогресс страниц
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          scenes.length,
                          (index) => Container(
                            width: index == currentPage.value ? 24 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: index == currentPage.value
                                  ? AppColors.primary
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // PageView со сценами
                    Expanded(
                      child: PageView.builder(
                        controller: pageController,
                        onPageChanged: (index) => currentPage.value = index,
                        itemCount: scenes.length,
                        itemBuilder: (context, index) {
                          final scene = scenes[index];
                          final sceneVariants = variants[scene.id];
                          
                          // Получаем выбранные варианты или оригиналы
                          final selectedText = sceneVariants?.textVariants
                                  .where((v) => v.isSelected)
                                  .firstOrNull
                                  ?.text ??
                              scene.shortSummary;
                          final selectedImageUrl = sceneVariants?.imageVariants
                                  .where((v) => v.isSelected)
                                  .firstOrNull
                                  ?.imageUrl ??
                              scene.finalUrl ??
                              scene.draftUrl;

                          return _buildScenePreview(
                            context,
                            index + 1,
                            scenes.length,
                            selectedText,
                            selectedImageUrl,
                            sceneVariants?.textVariants.length ?? 1,
                            sceneVariants?.imageVariants.length ?? 1,
                          );
                        },
                      ),
                    ),
                    
                    // Нижняя панель с кнопками
                    Container(
                      padding: AppSpacing.paddingMD,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Ошибка
                            if (errorMessage.value != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: AppSpacing.paddingSM,
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  errorMessage.value!,
                                  style: safeCopyWith(
                                    AppTypography.bodySmall,
                                    color: AppColors.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            
                            // Информация о защите
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.security,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Это превью с водяным знаком. Финальная версия будет в высоком качестве.',
                                      style: safeCopyWith(
                                        AppTypography.bodySmall,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Кнопки навигации
                            Row(
                              children: [
                                if (currentPage.value > 0)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        pageController.previousPage(
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                                      icon: const Icon(Icons.arrow_back),
                                      label: const Text('Назад'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: Colors.white54),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                if (currentPage.value > 0)
                                  const SizedBox(width: 12),
                                Expanded(
                                  flex: currentPage.value == scenes.length - 1 ? 2 : 1,
                                  child: currentPage.value == scenes.length - 1
                                      ? AppMagicButton(
                                          onPressed: isLoading.value ? null : handleFinalize,
                                          isLoading: isLoading.value,
                                          fullWidth: true,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.auto_awesome,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Финализировать книгу',
                                                style: safeCopyWith(
                                                  AppTypography.labelLarge,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : ElevatedButton.icon(
                                          onPressed: () {
                                            pageController.nextPage(
                                              duration: const Duration(milliseconds: 300),
                                              curve: Curves.easeInOut,
                                            );
                                          },
                                          icon: const Text('Далее'),
                                          label: const Icon(Icons.arrow_forward),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const LoadingWidget(),
              error: (error, stack) => ErrorDisplayWidget(
                error: error,
                onRetry: () => ref.invalidate(bookScenesProvider(bookId)),
              ),
            );
          },
          loading: () => const LoadingWidget(),
          error: (error, stack) => ErrorDisplayWidget(
            error: error,
            onRetry: () => ref.invalidate(bookProvider(bookId)),
          ),
        ),
      ),
    );
  }

  Widget _buildScenePreview(
    BuildContext context,
    int pageNumber,
    int totalPages,
    String text,
    String? imageUrl,
    int textVariantsCount,
    int imageVariantsCount,
  ) {
    return Padding(
      padding: AppSpacing.paddingMD,
      child: Column(
        children: [
          // Заголовок страницы
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Страница $pageNumber из $totalPages',
                  style: safeCopyWith(
                    AppTypography.labelLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                // Индикаторы вариантов
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '📝$textVariantsCount 🖼️$imageVariantsCount',
                    style: safeCopyWith(
                      AppTypography.labelSmall,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Превью страницы с защитой
          Expanded(
            child: ProtectedBookPreview(
              isPaid: false,
              isPreview: true,
              child: AppMagicCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    // Изображение
                    Expanded(
                      flex: 3,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: imageUrl != null
                            ? RoundedImage(
                                imageUrl: imageUrl,
                                width: double.infinity,
                                height: double.infinity,
                                radius: 0,
                              )
                            : Container(
                                color: AppColors.surfaceVariant,
                                child: Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 64,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    
                    // Текст
                    Expanded(
                      flex: 2,
                      child: Container(
                        width: double.infinity,
                        padding: AppSpacing.paddingMD,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            text,
                            style: safeCopyWith(
                              AppTypography.bodyLarge,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

