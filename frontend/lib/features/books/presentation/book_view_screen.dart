import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes/route_names.dart';
import '../../../core/presentation/layouts/app_page.dart';
import '../../../core/presentation/design_system/app_colors.dart';
import '../../../core/presentation/design_system/app_typography.dart';
import '../../../core/presentation/design_system/app_spacing.dart';
import '../../../core/presentation/widgets/buttons/app_button.dart';
import '../../../core/presentation/widgets/buttons/app_magic_button.dart';
import '../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../core/widgets/rounded_image.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../ui/components/page_flip_animation.dart';
import '../../../ui/components/asset_icon.dart';
import '../../../core/api/backend_api.dart';
import '../data/book_providers.dart';

class BookViewScreen extends HookConsumerWidget {
  final String bookId;

  const BookViewScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookProvider(bookId));
    final scenesAsync = ref.watch(bookScenesProvider(bookId));
    final pageController = usePageController();
    final currentPageIndex = useState(0);

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_final_story.png',
      overlayOpacity: 0.2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: bookAsync.when(
            data: (book) => book.title,
            loading: () => 'Книга',
            error: (_, __) => 'Книга',
          ),
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
          actions: [
            bookAsync.when(
              data: (book) => PopupMenuButton<String>(
                icon: AssetIcon(
                  assetPath: AppIcons.library,
                  size: 24,
                  color: AppColors.onBackground,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        AssetIcon(
                          assetPath: AppIcons.edit,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const Text('Редактировать'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        AssetIcon(
                          assetPath: AppIcons.delete,
                          size: 20,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Удалить',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'delete') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Удалить книгу?'),
                        content: Text(
                          'Вы уверены, что хотите удалить книгу "${book.title}"?',
                        ),
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
                            child: const Text('Удалить'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && context.mounted) {
                      try {
                        final api = ref.read(backendApiProvider);
                        await api.deleteBook(book.id);
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Книга "${book.title}" удалена'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          context.go(RouteNames.books);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Ошибка: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    }
                  }
                },
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        body: bookAsync.when(
          data: (book) {
            return scenesAsync.when(
              data: (scenes) {
                if (scenes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AssetIcon(
                          assetPath: AppIcons.library,
                          size: 64,
                          color: AppColors.onSurfaceVariant.withOpacity(0.5),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Сцены еще не созданы',
                          style: AppTypography.headlineSmall,
                        ),
                      ],
                    ),
                  );
                }

                final sortedScenes = [...scenes]..sort((a, b) => a.order.compareTo(b.order));
                final bookStatus = book.status;
                final canEdit = bookStatus == 'draft' || bookStatus == 'editing';

                return Column(
                  children: [
                    // Кнопки действий
                    if (canEdit)
                      Padding(
                        padding: AppSpacing.paddingMD,
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          alignment: WrapAlignment.center,
                          children: [
                            AppMagicButton(
                              onPressed: () {
                                final scene = sortedScenes[currentPageIndex.value];
                                context.push(RouteNames.bookSceneEdit.replaceAll(':id', bookId).replaceAll(':index', '${scene.order - 1}'));
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AssetIcon(
                                    assetPath: AppIcons.edit,
                                    size: 20,
                                    color: AppColors.onPrimary,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    'Редактировать',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: AppColors.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (bookStatus == 'editing')
                              AppButton(
                                text: 'Финализировать',
                                iconAsset: AppIcons.secureBook,
                                onPressed: () {
                                  context.push(RouteNames.bookFinalize.replaceAll(':id', bookId));
                                },
                              ),
                          ],
                        ),
                      ),

                    // Страницы с анимацией переворота
                    Expanded(
                      child: PageView.builder(
                        controller: pageController,
                        onPageChanged: (index) {
                          currentPageIndex.value = index;
                        },
                        itemCount: sortedScenes.length,
                        itemBuilder: (context, index) {
                          final scene = sortedScenes[index];
                          final hasImage = scene.finalUrl != null || scene.draftUrl != null;

                          return Padding(
                            padding: AppSpacing.paddingMD,
                            child: PageFlipAnimation(
                              frontPage: BookPage(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Padding(
                                      padding: AppSpacing.paddingLG,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Заголовок сцены
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient: AppColors.primaryGradient,
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Text(
                                                    'Сцена ${scene.order}',
                                                    style: AppTypography.labelMedium.copyWith(
                                                      color: AppColors.onPrimary,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              if (scene.draftUrl != null && scene.finalUrl == null) ...[
                                                const SizedBox(width: AppSpacing.sm),
                                                Flexible(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.warning.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(20),
                                                      border: Border.all(color: AppColors.warning),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        AssetIcon(
                                                          assetPath: AppIcons.draftPages,
                                                          size: 16,
                                                          color: AppColors.warning,
                                                        ),
                                                        const SizedBox(width: AppSpacing.xs),
                                                        Flexible(
                                                          child: Text(
                                                            'Черновик',
                                                            style: AppTypography.labelSmall.copyWith(
                                                              color: AppColors.warning,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          
                                          const SizedBox(height: AppSpacing.lg),
                                          
                                          // Изображение
                                          if (hasImage)
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(16),
                                                child: RoundedImage(
                                                  imageUrl: scene.finalUrl ?? scene.draftUrl,
                                                  height: double.infinity,
                                                  width: double.infinity,
                                                  radius: 16,
                                                ),
                                              ),
                                            ),
                                          
                                          const SizedBox(height: AppSpacing.lg),
                                          
                                          // Текст
                                          Flexible(
                                            child: SingleChildScrollView(
                                              child: Text(
                                                scene.shortSummary,
                                                style: AppTypography.bodyLarge,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Индикатор страниц
                    Padding(
                      padding: AppSpacing.paddingMD,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: AssetIcon(
                              assetPath: AppIcons.back,
                              size: 20,
                              color: currentPageIndex.value > 0
                                  ? AppColors.onSurface
                                  : AppColors.onSurfaceVariant,
                            ),
                            onPressed: currentPageIndex.value > 0
                                ? () {
                                    pageController.previousPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : null,
                          ),
                          Padding(
                            padding: AppSpacing.paddingHMD,
                            child: Text(
                              '${currentPageIndex.value + 1} / ${sortedScenes.length}',
                              style: AppTypography.labelLarge,
                            ),
                          ),
                          IconButton(
                            icon: Transform.rotate(
                              angle: 3.14159, // 180 градусов
                              child: AssetIcon(
                                assetPath: AppIcons.back,
                                size: 20,
                                color: currentPageIndex.value < sortedScenes.length - 1
                                    ? AppColors.onSurface
                                    : AppColors.onSurfaceVariant,
                              ),
                            ),
                            onPressed: currentPageIndex.value < sortedScenes.length - 1
                                ? () {
                                    pageController.nextPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : null,
                          ),
                        ],
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
}
