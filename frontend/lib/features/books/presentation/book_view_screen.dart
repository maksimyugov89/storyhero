import 'dart:async';
import 'package:flutter/material.dart';
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
import '../../../core/utils/text_style_helpers.dart';

class BookViewScreen extends ConsumerStatefulWidget {
  final String bookId;

  const BookViewScreen({super.key, required this.bookId});

  @override
  ConsumerState<BookViewScreen> createState() => _BookViewScreenState();
}

class _BookViewScreenState extends ConsumerState<BookViewScreen> {
  Timer? _imagePollingTimer;
  bool _isDisposed = false;
  PageController? _pageController;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Запускаем polling для проверки изображений при первой загрузке
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        _startImagePolling();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _imagePollingTimer?.cancel();
    _imagePollingTimer = null;
    _pageController?.dispose();
    _pageController = null;
    super.dispose();
  }

  void _startImagePolling() {
    if (_isDisposed || !mounted) return;
    
    _imagePollingTimer?.cancel();
    
    // Polling каждые 5 секунд для проверки новых изображений
    _imagePollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }

      try {
        // Загружаем обновленные сцены
        if (!_isDisposed && mounted) {
          ref.invalidate(bookScenesProvider(widget.bookId));
        }
        
        final scenesAsync = ref.read(bookScenesProvider(widget.bookId));
        await scenesAsync.when(
          data: (scenes) {
            // Проверяем, все ли изображения созданы
            // Используем только finalUrl (image_url из API)
            // Безопасная проверка без force unwrap с проверкой на пустой список
            final allImagesReady = scenes.isNotEmpty &&
                scenes.every((scene) => 
                  scene.finalUrl?.isNotEmpty ?? false
                );
            
            if (allImagesReady) {
              // Все изображения готовы - останавливаем polling
              timer.cancel();
              _imagePollingTimer?.cancel();
            }
          },
          loading: () {
            // Продолжаем polling при загрузке
          },
          error: (error, stack) {
            // Логируем ошибку, но продолжаем polling
            print('[BookViewScreen] Ошибка при проверке изображений: $error');
          },
        );
      } catch (e) {
        // Ошибка при загрузке - продолжаем polling
        print('[BookViewScreen] Ошибка в polling: $e');
      }
    });
    
    // Останавливаем polling через 10 минут (максимальное время ожидания)
    Future.delayed(const Duration(minutes: 10), () {
      if (!_isDisposed && mounted) {
        _imagePollingTimer?.cancel();
        _imagePollingTimer = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookProvider(widget.bookId));
    final scenesAsync = ref.watch(bookScenesProvider(widget.bookId));

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
                          style: safeTextStyle(color: AppColors.error),
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
                        
                        // Обновляем список книг после успешного удаления (204 No Content)
                        ref.invalidate(booksProvider);
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Книга "${book.title}" удалена'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          // Переходим на список книг ДО инвалидации провайдеров удаленной книги
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
                
                // Проверяем статус изображений
                // Используем только finalUrl (image_url из API)
                // Безопасная проверка без force unwrap
                final imagesReady = sortedScenes.where((s) => 
                  s.finalUrl?.isNotEmpty ?? false
                ).length;
                final totalScenes = sortedScenes.length;
                // Проверка готовности всех изображений с проверкой на пустой список
                final allImagesReady = totalScenes > 0 && imagesReady == totalScenes;

                return Column(
                  children: [
                    // Индикатор прогресса создания изображений
                    if (!allImagesReady)
                      Container(
                        margin: AppSpacing.paddingMD,
                        padding: AppSpacing.paddingMD,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Создано изображений: $imagesReady из $totalScenes',
                              style: safeCopyWith(
                                AppTypography.bodyMedium,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
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
                                final scene = sortedScenes[_currentPageIndex];
                                context.push(RouteNames.bookSceneEdit.replaceAll(':id', widget.bookId).replaceAll(':index', '${scene.order - 1}'));
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
                                    style: safeCopyWith(
                                      AppTypography.labelLarge,
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
                                  context.push(RouteNames.bookFinalize.replaceAll(':id', widget.bookId));
                                },
                              ),
                          ],
                        ),
                      ),

                    // Страницы с анимацией переворота
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPageIndex = index;
                          });
                        },
                        itemCount: sortedScenes.length,
                        itemBuilder: (context, index) {
                          final scene = sortedScenes[index];
                          // Используем только finalUrl (image_url из API)
                          // Безопасная проверка без force unwrap
                          final hasImage = scene.finalUrl?.isNotEmpty ?? false;
                          final isLoading = !hasImage;

                          return Padding(
                            padding: AppSpacing.paddingMD,
                            child: PageFlipAnimation(
                              frontPage: BookPage(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (!constraints.maxWidth.isFinite || !constraints.maxHeight.isFinite || 
                                        constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
                                      return const SizedBox.shrink();
                                    }
                                    
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
                                                    style: safeCopyWith(
                                                      AppTypography.labelMedium,
                                                      color: AppColors.onPrimary,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          
                                          const SizedBox(height: AppSpacing.lg),
                                          
                                          // Изображение или placeholder
                                          Expanded(
                                            child: hasImage && scene.finalUrl != null
                                                ? ClipRRect(
                                                    borderRadius: BorderRadius.circular(16),
                                                    child: RoundedImage(
                                                      imageUrl: scene.finalUrl, // RoundedImage обрабатывает null/пустую строку
                                                      height: double.infinity,
                                                      width: double.infinity,
                                                      radius: 16,
                                                    ),
                                                  )
                                                : _buildImagePlaceholder(isLoading: isLoading),
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
                              color: _currentPageIndex > 0
                                  ? AppColors.onSurface
                                  : AppColors.onSurfaceVariant,
                            ),
                            onPressed: _currentPageIndex > 0
                                ? () {
                                    _pageController?.previousPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : null,
                          ),
                          Padding(
                            padding: AppSpacing.paddingHMD,
                            child: Text(
                              '${_currentPageIndex + 1} / ${sortedScenes.length}',
                              style: AppTypography.labelLarge,
                            ),
                          ),
                          IconButton(
                            icon: Transform.rotate(
                              angle: 3.14159, // 180 градусов
                              child: AssetIcon(
                                assetPath: AppIcons.back,
                                size: 20,
                                color: _currentPageIndex < sortedScenes.length - 1
                                    ? AppColors.onSurface
                                    : AppColors.onSurfaceVariant,
                              ),
                            ),
                            onPressed: _currentPageIndex < sortedScenes.length - 1
                                ? () {
                                    _pageController?.nextPage(
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
                onRetry: () => ref.invalidate(bookScenesProvider(widget.bookId)),
              ),
            );
          },
          loading: () => const LoadingWidget(),
          error: (error, stack) => ErrorDisplayWidget(
            error: error,
            onRetry: () => ref.invalidate(bookProvider(widget.bookId)),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder({required bool isLoading}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: isLoading
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Создание изображения...',
                  style: safeCopyWith(
                    AppTypography.bodyMedium,
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AssetIcon(
                    assetPath: AppIcons.library,
                    size: 48,
                    color: AppColors.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Изображение не готово',
                    style: safeCopyWith(
                      AppTypography.bodySmall,
                      color: AppColors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

class BookPage extends StatelessWidget {
  final Widget child;

  const BookPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}
