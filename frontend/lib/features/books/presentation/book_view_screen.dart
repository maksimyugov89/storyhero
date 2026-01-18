import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
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
import '../../../ui/layouts/desktop_container.dart';

class BookViewScreen extends ConsumerStatefulWidget {
  final String bookId;

  const BookViewScreen({super.key, required this.bookId});

  @override
  ConsumerState<BookViewScreen> createState() => _BookViewScreenState();
}

class _BookViewScreenState extends ConsumerState<BookViewScreen> {
  Timer? _imagePollingTimer;
  Timer? _countdownTimer; // Таймер обратного отсчета
  bool _isDisposed = false;
  PageController? _pageController;
  int _currentPageIndex = 0;
  final Map<int, bool> _pageFlipStates = {}; // Состояние переворота для каждой страницы
  final Map<int, bool> _pageFlipDirection = {}; // Направление переворота: true = вперед, false = назад
  DateTime? _generationStartTime; // Время начала генерации (для расчета таймера)

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
    _countdownTimer?.cancel();
    _countdownTimer = null;
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
            // Учитываем как finalUrl, так и draftUrl (черновые изображения)
            // Безопасная проверка без force unwrap с проверкой на пустой список
            final allImagesReady = scenes.isNotEmpty &&
                scenes.every((scene) => 
                  (scene.finalUrl?.isNotEmpty ?? false) || 
                  (scene.draftUrl?.isNotEmpty ?? false)
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
          leading: bookAsync.when(
            data: (book) {
              // Определяем фильтр на основе статуса книги
              final status = book.status;
              String filterParam = '';
              
              // Определяем фильтр: черновики или готовые
              if (status == 'draft' || status == 'editing') {
                filterParam = '?filter=drafts';
              } else if (status == 'completed' || status == 'finalized' || status == 'final') {
                filterParam = '?filter=completed';
              }
              
              return IconButton(
                icon: AssetIcon(
                  assetPath: AppIcons.back,
                  size: 24,
                  color: AppColors.onBackground,
                ),
                onPressed: () {
                  // Переходим на список книг с нужным фильтром
                  context.go('${RouteNames.books}$filterParam');
                },
              );
            },
            loading: () => IconButton(
              icon: AssetIcon(
                assetPath: AppIcons.back,
                size: 24,
                color: AppColors.onBackground,
              ),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RouteNames.books);
                }
              },
            ),
            error: (_, __) => IconButton(
              icon: AssetIcon(
                assetPath: AppIcons.back,
                size: 24,
                color: AppColors.onBackground,
              ),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RouteNames.books);
                }
              },
            ),
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
                        
                        // Останавливаем polling перед удалением
                        _imagePollingTimer?.cancel();
                        _imagePollingTimer = null;
                        _countdownTimer?.cancel();
                        _countdownTimer = null;
                        
                        // Инвалидируем провайдеры сцен ДО удаления, чтобы избежать ошибок
                        ref.invalidate(bookScenesProvider(widget.bookId));
                        ref.invalidate(bookProvider(widget.bookId));
                        
                        await api.deleteBook(book.id);
                        
                        // Обновляем список книг после успешного удаления
                        ref.invalidate(booksProvider);
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Книга "${book.title}" удалена'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          // Переходим на список книг после инвалидации провайдеров
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
                      mainAxisSize: MainAxisSize.min,
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
                
                // Проверяем, готова ли книга и не оплачена ли она
                final isCompleted = bookStatus == 'completed' || 
                                   bookStatus == 'finalized' || 
                                   bookStatus == 'final';
                final needsPayment = isCompleted && !book.isPaid;
                
                // Проверяем статус изображений
                // Учитываем как finalUrl, так и draftUrl (черновые изображения)
                // Безопасная проверка без force unwrap
                final imagesReady = sortedScenes.where((s) => 
                  (s.finalUrl?.isNotEmpty ?? false) || 
                  (s.draftUrl?.isNotEmpty ?? false)
                ).length;
                final totalScenes = sortedScenes.length;
                // Проверка готовности всех изображений с проверкой на пустой список
                final allImagesReady = totalScenes > 0 && imagesReady == totalScenes;

                return DesktopContainer(
                  maxWidth: 1200,
                  child: Column(
                    children: [
                    // Индикатор прогресса создания изображений
                    if (!allImagesReady)
                      Container(
                        margin: AppSpacing.paddingMD,
                        padding: AppSpacing.paddingMD,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.15),
                              AppColors.secondary.withOpacity(0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Lottie анимация вместо CircularProgressIndicator
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: Lottie.asset(
                                    'assets/animations/login_magic_swirl.json',
                                    fit: BoxFit.contain,
                                    repeat: true,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '🎨 Создание изображений',
                                        style: safeCopyWith(
                                          AppTypography.bodyMedium,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '$imagesReady из $totalScenes (${totalScenes > 0 ? ((imagesReady / totalScenes) * 100).toStringAsFixed(0) : 0}%)',
                                        style: safeCopyWith(
                                          AppTypography.bodySmall,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Прогресс бар
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: totalScenes > 0 ? imagesReady / totalScenes : 0,
                                backgroundColor: AppColors.surfaceVariant.withOpacity(0.3),
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Таймер обратного отсчета
                            Builder(
                              builder: (context) {
                                final remainingImages = totalScenes - imagesReady;
                                if (remainingImages <= 0) {
                                  return const SizedBox.shrink();
                                }
                                
                                // Среднее время генерации одного изображения: 12 секунд
                                const avgTimePerImage = Duration(seconds: 12);
                                final estimatedTime = avgTimePerImage * remainingImages;
                                
                                // Форматируем время
                                final minutes = estimatedTime.inMinutes;
                                final seconds = estimatedTime.inSeconds % 60;
                                String timeText;
                                if (minutes > 0) {
                                  timeText = '$minutes ${minutes == 1 ? 'минута' : minutes < 5 ? 'минуты' : 'минут'}';
                                  if (seconds > 0) {
                                    timeText += ' $seconds ${seconds == 1 ? 'секунда' : seconds < 5 ? 'секунды' : 'секунд'}';
                                  }
                                } else {
                                  timeText = '$seconds ${seconds == 1 ? 'секунда' : seconds < 5 ? 'секунды' : 'секунд'}';
                                }
                                
                                return Text(
                                  '⏱️ Примерное время до завершения: $timeText',
                                  style: safeCopyWith(
                                    AppTypography.bodySmall,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '✏️ Пока можете редактировать текст!',
                              style: safeCopyWith(
                                AppTypography.bodySmall,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Кнопки действий
                    if (canEdit)
                      Padding(
                        padding: AppSpacing.paddingMD,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Кнопки редактирования текущей сцены
                            Row(
                              children: [
                                // Кнопка редактирования текста (всегда доступна)
                                Expanded(
                                  child: _buildEditButton(
                                    icon: Icons.text_fields,
                                    label: 'Текст',
                                    isEnabled: true,
                                    onPressed: () {
                                      // Используем _currentPageIndex напрямую, так как индексация начинается с 0 (обложка)
                                      context.push(RouteNames.bookTextEdit
                                          .replaceAll(':id', widget.bookId)
                                          .replaceAll(':index', '$_currentPageIndex'));
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                // Кнопка редактирования изображения (если есть finalUrl или draftUrl)
                                Expanded(
                                  child: _buildEditButton(
                                    icon: Icons.image_outlined,
                                    label: 'Изображение',
                                    isEnabled: (sortedScenes[_currentPageIndex].finalUrl?.isNotEmpty ?? false) ||
                                             (sortedScenes[_currentPageIndex].draftUrl?.isNotEmpty ?? false),
                                    onPressed: () {
                                      // Используем _currentPageIndex напрямую, так как индексация начинается с 0 (обложка)
                                      context.push(RouteNames.bookImageEdit
                                          .replaceAll(':id', widget.bookId)
                                          .replaceAll(':index', '$_currentPageIndex'));
                                    },
                                  ),
                                ),
                              ],
                            ),
                            
                            // Кнопка отправки на финальную генерацию (для черновиков)
                            if (canEdit && (bookStatus == 'draft' || bookStatus == 'editing')) ...[
                              const SizedBox(height: AppSpacing.md),
                              AppMagicButton(
                                onPressed: () async {
                                  // Показываем диалог подтверждения
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Row(
                                        children: [
                                          Icon(Icons.auto_awesome, color: AppColors.primary, size: 28),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: const Text('Отправить на финальную генерацию?'),
                                          ),
                                        ],
                                      ),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Книга будет отправлена на генерацию финальной версии с учетом всех ваших изменений:',
                                              style: AppTypography.bodyMedium,
                                            ),
                                            const SizedBox(height: 12),
                                            _buildFeatureRow(Icons.text_fields, 'Изменения в тексте'),
                                            _buildFeatureRow(Icons.image, 'Изменения в изображениях'),
                                            _buildFeatureRow(Icons.edit, 'Все правки сцен'),
                                            const SizedBox(height: 12),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'После генерации вы сможете финализировать книгу',
                                                      style: safeCopyWith(
                                                        AppTypography.bodySmall,
                                                        color: AppColors.primary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(false),
                                          child: const Text('Отмена'),
                                        ),
                                        AppMagicButton(
                                          onPressed: () => Navigator.of(ctx).pop(true),
                                          child: const Text('Отправить'),
                                        ),
                                      ],
                                    ),
                                  );
                                  
                                  if (confirmed == true && context.mounted) {
                                    // Показываем индикатор загрузки
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Row(
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Text('Отправка на генерацию...'),
                                          ],
                                        ),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    
                                    try {
                                      final api = ref.read(backendApiProvider);
                                      final response = await api.generateFinalVersion(widget.bookId);
                                      
                                      // Обновляем данные книги
                                      ref.invalidate(bookProvider(widget.bookId));
                                      ref.invalidate(bookScenesProvider(widget.bookId));
                                      
                                      if (context.mounted) {
                                        // Переходим на экран отслеживания статуса генерации
                                        context.go(RouteNames.taskStatus.replaceAll(':id', response.taskId));
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Ошибка: ${e.toString().replaceAll('Exception: ', '')}'),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                fullWidth: true,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                                    const SizedBox(width: AppSpacing.sm),
                                    Flexible(
                                      child: Text(
                                        '🚀 Отправить на финальную генерацию',
                                        style: safeCopyWith(
                                          AppTypography.labelLarge,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            
                            // Кнопка финализации (когда все готово)
                            if (allImagesReady && bookStatus == 'editing') ...[
                              const SizedBox(height: AppSpacing.md),
                              AppButton(
                                text: '✨ Финализировать книгу',
                                iconAsset: AppIcons.secureBook,
                                fullWidth: true,
                                onPressed: () {
                                  context.push(RouteNames.bookFinalize.replaceAll(':id', widget.bookId));
                                },
                              ),
                            ],
                          ],
                        ),
                      ),

                    // Кнопка покупки PDF для готовых, но неоплаченных книг
                    if (needsPayment)
                      Padding(
                        padding: AppSpacing.paddingMD,
                        child: AppMagicButton(
                          onPressed: () {
                            context.go(RouteNames.bookComplete.replaceAll(':id', widget.bookId));
                          },
                          fullWidth: true,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.credit_card, color: Colors.white),
                              const SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: Text(
                                  'Купить PDF за 499 ₽',
                                  style: safeCopyWith(
                                    AppTypography.labelLarge,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Кнопка перехода к скачиванию/заказу для оплаченных книг
                    if (isCompleted && book.isPaid)
                      Padding(
                        padding: AppSpacing.paddingMD,
                        child: AppMagicButton(
                          onPressed: () {
                            context.go(RouteNames.bookComplete.replaceAll(':id', widget.bookId));
                          },
                          fullWidth: true,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.download, color: Colors.white),
                              const SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: Text(
                                  'Перейти к скачиванию и заказу',
                                  style: safeCopyWith(
                                    AppTypography.labelLarge,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Страницы с анимацией переворота
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPageIndex = index;
                            // Сбрасываем состояние переворота только для предыдущей страницы
                            // Не сбрасываем для текущей, чтобы анимация могла завершиться
                            final prevIndex = index - 1;
                            if (prevIndex >= 0) {
                              _pageFlipStates.remove(prevIndex);
                              _pageFlipDirection.remove(prevIndex);
                            }
                          });
                        },
                        itemCount: sortedScenes.length,
                        itemBuilder: (context, index) {
                          final scene = sortedScenes[index];
                          // Учитываем как finalUrl, так и draftUrl (черновые изображения)
                          // Безопасная проверка без force unwrap
                          final hasImage = (scene.finalUrl?.isNotEmpty ?? false) || 
                                          (scene.draftUrl?.isNotEmpty ?? false);
                          final isLoading = !hasImage;

                          // Определяем следующую и предыдущую сцены для анимации
                          final nextScene = index < sortedScenes.length - 1 ? sortedScenes[index + 1] : null;
                          final prevScene = index > 0 ? sortedScenes[index - 1] : null;
                          
                          return AnimatedBuilder(
                            animation: _pageController!,
                            builder: (context, child) {
                              final controller = _pageController;
                              final page = controller != null && controller.hasClients
                                  ? (controller.page ?? _currentPageIndex.toDouble())
                                  : _currentPageIndex.toDouble();
                              final distance = (page - index).abs().clamp(0.0, 1.0);
                              final opacity = 1 - (distance * 0.25);
                              final scale = 0.98 + (1 - distance) * 0.02;

                              return Opacity(
                                opacity: opacity,
                                child: Transform.scale(
                                  scale: scale,
                                  child: child,
                                ),
                              );
                            },
                            child: Padding(
                              padding: AppSpacing.paddingMD,
                              child: GestureDetector(
                                onTapDown: (details) {
                                  // Определяем, на какую половину страницы нажали
                                  final screenWidth = MediaQuery.of(context).size.width;
                                  final tapX = details.globalPosition.dx;
                                  
                                  // Если нажали на правую половину - следующая страница
                                  if (tapX > screenWidth / 2 && index < sortedScenes.length - 1) {
                                    // Запускаем анимацию переворота вперед
                                    setState(() {
                                      _pageFlipStates[index] = true;
                                      _pageFlipDirection[index] = true; // вперед
                                    });
                                  }
                                  // Если нажали на левую половину - предыдущая страница
                                  else if (tapX < screenWidth / 2 && index > 0) {
                                    // Запускаем анимацию переворота назад
                                    setState(() {
                                      _pageFlipStates[index] = true;
                                      _pageFlipDirection[index] = false; // назад
                                    });
                                  }
                                },
                                child: PageFlipAnimation(
                                  isFlipped: _pageFlipStates[index] ?? false,
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
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              
                                              const SizedBox(height: AppSpacing.lg),
                                              
                                              // Изображение или placeholder
                                              Flexible(
                                                flex: 3,
                                                child: Align(
                                                  alignment: Alignment.topCenter,
                                                  child: ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                      maxHeight: constraints.maxHeight * 0.48, // Ограничение высоты
                                                      minHeight: 150,
                                                    ),
                                                    child: TweenAnimationBuilder<double>(
                                                      tween: Tween(begin: 1.03, end: 1.0),
                                                      duration: const Duration(milliseconds: 420),
                                                      curve: Curves.easeOutCubic,
                                                      builder: (context, value, child) {
                                                        return Transform.scale(
                                                          scale: value,
                                                          child: child,
                                                        );
                                                      },
                                                      child: hasImage && (scene.finalUrl != null || scene.draftUrl != null)
                                                          ? ClipRRect(
                                                              borderRadius: BorderRadius.circular(16),
                                                              child: RoundedImage(
                                                                imageUrl: scene.finalUrl ?? scene.draftUrl,
                                                                height: double.infinity,
                                                                width: double.infinity,
                                                                radius: 16,
                                                              ),
                                                            )
                                                          : ClipRRect(
                                                              borderRadius: BorderRadius.circular(16),
                                                              child: _buildImagePlaceholder(isLoading: isLoading),
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              
                                              const SizedBox(height: AppSpacing.lg),
                                              
                                              // Текст с ограничением высоты
                                              Flexible(
                                                child: ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    maxHeight: constraints.maxHeight * 0.25, // Максимум 25% от высоты
                                                  ),
                                                  child: SingleChildScrollView(
                                                    child: Align(
                                                      alignment: Alignment.topCenter,
                                                      child: ConstrainedBox(
                                                        constraints: const BoxConstraints(maxWidth: 720),
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                                          child: Text(
                                                            scene.shortSummary,
                                                            style: AppTypography.bodyLarge,
                                                            maxLines: null,
                                                            overflow: TextOverflow.visible,
                                                          ),
                                                        ),
                                                      ),
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
                                  backPage: nextScene != null
                                      ? BookPage(
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
                                                              'Сцена ${nextScene.order}',
                                                              style: safeCopyWith(
                                                                AppTypography.labelMedium,
                                                                color: AppColors.onPrimary,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                              maxLines: 1,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: AppSpacing.lg),
                                                    Flexible(
                                                      flex: 3,
                                                      child: Align(
                                                        alignment: Alignment.topCenter,
                                                        child: ConstrainedBox(
                                                          constraints: BoxConstraints(
                                                            maxHeight: constraints.maxHeight * 0.48,
                                                            minHeight: 150,
                                                          ),
                                                          child: TweenAnimationBuilder<double>(
                                                            tween: Tween(begin: 1.03, end: 1.0),
                                                            duration: const Duration(milliseconds: 420),
                                                            curve: Curves.easeOutCubic,
                                                            builder: (context, value, child) {
                                                              return Transform.scale(
                                                                scale: value,
                                                                child: child,
                                                              );
                                                            },
                                                            child: ((nextScene.finalUrl?.isNotEmpty ?? false) || (nextScene.draftUrl?.isNotEmpty ?? false)) && 
                                                                   (nextScene.finalUrl != null || nextScene.draftUrl != null)
                                                                ? ClipRRect(
                                                                    borderRadius: BorderRadius.circular(16),
                                                                    child: RoundedImage(
                                                                      imageUrl: nextScene.finalUrl ?? nextScene.draftUrl,
                                                                      height: double.infinity,
                                                                      width: double.infinity,
                                                                      radius: 16,
                                                                    ),
                                                                  )
                                                                : ClipRRect(
                                                                    borderRadius: BorderRadius.circular(16),
                                                                    child: _buildImagePlaceholder(isLoading: !((nextScene.finalUrl?.isNotEmpty ?? false) || (nextScene.draftUrl?.isNotEmpty ?? false))),
                                                                  ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: AppSpacing.lg),
                                                    Flexible(
                                                      child: ConstrainedBox(
                                                        constraints: BoxConstraints(
                                                          maxHeight: constraints.maxHeight * 0.25, // Максимум 25% от высоты
                                                        ),
                                                        child: SingleChildScrollView(
                                                          child: Align(
                                                            alignment: Alignment.topCenter,
                                                            child: ConstrainedBox(
                                                              constraints: const BoxConstraints(maxWidth: 720),
                                                              child: Padding(
                                                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                                                child: Text(
                                                                  nextScene.shortSummary,
                                                                  style: AppTypography.bodyLarge,
                                                                  maxLines: null,
                                                                  overflow: TextOverflow.visible,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                      : null,
                                  onFlipComplete: () {
                                    // После завершения анимации переворота переключаем страницу
                                    if (mounted) {
                                      final wasFlipped = _pageFlipStates[index] ?? false;
                                      final direction = _pageFlipDirection[index] ?? true;
                                      
                                      if (wasFlipped) {
                                        // Небольшая задержка для более плавного перехода
                                        Future.delayed(const Duration(milliseconds: 50), () {
                                          if (!mounted) return;
                                          
                                          // Переключаем страницу в нужном направлении
                                          if (direction && index < sortedScenes.length - 1) {
                                            // Вперед - следующая страница
                                            _pageController?.nextPage(
                                              duration: const Duration(milliseconds: 400),
                                              curve: Curves.easeInOutCubic,
                                            );
                                          } else if (!direction && index > 0) {
                                            // Назад - предыдущая страница
                                            _pageController?.previousPage(
                                              duration: const Duration(milliseconds: 400),
                                              curve: Curves.easeInOutCubic,
                                            );
                                          }
                                          
                                          // Сбрасываем состояние переворота после небольшой задержки
                                          Future.delayed(const Duration(milliseconds: 100), () {
                                            if (mounted) {
                                              setState(() {
                                                _pageFlipStates.remove(index);
                                                _pageFlipDirection.remove(index);
                                              });
                                            }
                                          });
                                        });
                                      }
                                    }
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
                      child: Align(
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
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
                                          duration: const Duration(milliseconds: 400),
                                          curve: Curves.easeInOutCubic,
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
                                          duration: const Duration(milliseconds: 400),
                                          curve: Curves.easeInOutCubic,
                                        );
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
              },
              loading: () => const LoadingWidget(),
              error: (error, stack) {
                print('[BookViewScreen] Ошибка загрузки сцен: $error');
                return ErrorDisplayWidget(
                  error: error,
                  customMessage: 'Не удалось загрузить сцены книги. Попробуйте обновить страницу.',
                  onRetry: () {
                    ref.invalidate(bookScenesProvider(widget.bookId));
                    ref.invalidate(bookProvider(widget.bookId));
                  },
                  onExit: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(RouteNames.books);
                    }
                  },
                );
              },
            );
          },
          loading: () => const LoadingWidget(),
          error: (error, stack) {
            print('[BookViewScreen] Ошибка загрузки книги: $error');
            print('[BookViewScreen] Stack trace: $stack');
            return ErrorDisplayWidget(
              error: error,
              customMessage: error.toString().contains('не найдена') || error.toString().contains('404')
                  ? 'Книга не найдена. Возможно, она была удалена или ID книги некорректен.'
                  : null,
              onRetry: () {
                // Инвалидируем оба провайдера
                ref.invalidate(bookProvider(widget.bookId));
                ref.invalidate(bookScenesProvider(widget.bookId));
                // Также обновляем список книг
                ref.invalidate(booksProvider);
              },
              onExit: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RouteNames.books);
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEditButton({
    required IconData icon,
    required String label,
    required bool isEnabled,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isEnabled
              ? LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.2),
                    AppColors.secondary.withOpacity(0.2),
                  ],
                )
              : null,
          color: isEnabled ? null : AppColors.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled
                ? AppColors.primary.withOpacity(0.5)
                : AppColors.surfaceVariant,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isEnabled ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: safeCopyWith(
                  AppTypography.labelLarge,
                  color: isEnabled ? AppColors.primary : AppColors.onSurfaceVariant,
                  fontWeight: isEnabled ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            if (!isEnabled) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.hourglass_empty,
                size: 14,
                color: AppColors.onSurfaceVariant.withOpacity(0.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder({required bool isLoading}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 150,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: isLoading
          ? Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
                horizontal: AppSpacing.md,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lottie анимация загрузки
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Lottie.asset(
                      'assets/animations/login_magic_swirl.json',
                      fit: BoxFit.contain,
                      repeat: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      child: Text(
                        '✨ Создание изображения...',
                        style: safeCopyWith(
                          AppTypography.bodyMedium,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      child: Text(
                        'Магия в процессе',
                        style: safeCopyWith(
                          AppTypography.bodySmall,
                          color: AppColors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AssetIcon(
                      assetPath: AppIcons.library,
                      size: 48,
                      color: AppColors.onSurfaceVariant.withOpacity(0.5),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      child: Text(
                        'Изображение не готово',
                        style: safeCopyWith(
                          AppTypography.bodySmall,
                          color: AppColors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppTypography.bodySmall,
          ),
        ],
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
