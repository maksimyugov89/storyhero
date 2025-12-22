import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../../app/routes/route_names.dart';
import '../../../../core/api/backend_api.dart';
import '../../../../core/models/task_status.dart';
import '../../../../core/models/book_generation_step.dart';
import '../../../../core/models/book.dart';
import '../../../../core/models/child.dart';
import '../../../../core/presentation/layouts/app_page.dart';
import '../../../../core/presentation/design_system/app_colors.dart';
import '../../../../core/presentation/design_system/app_typography.dart';
import '../../../../core/presentation/design_system/app_spacing.dart';
import '../../../../core/utils/text_style_helpers.dart';
import '../../../../core/presentation/widgets/feedback/app_loader.dart';
import '../../../../core/presentation/widgets/feedback/app_progress_bar.dart';
import '../../../../core/presentation/widgets/feedback/app_step_list.dart';
import '../../../../core/presentation/widgets/navigation/app_app_bar.dart';
import '../../../../core/presentation/widgets/buttons/app_button.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../ui/components/asset_icon.dart';
import 'create_book_screen.dart';

final taskStatusProvider = FutureProvider.family<TaskStatus, String>(
  (ref, taskId) async {
    final api = ref.watch(backendApiProvider);
    try {
      return await api.checkTaskStatus(taskId);
    } on TaskNotFoundException catch (e) {
      // При 404 создаем TaskStatus со статусом 'lost'
      // Это позволит UI обработать ситуацию
      print('[TaskStatusProvider] Task not found: ${e.taskId}, creating lost status');
      return TaskStatus(
        id: taskId,
        status: 'lost',
        error: 'Задача была потеряна при перезапуске сервера',
      );
    }
  },
);

class TaskStatusScreen extends ConsumerStatefulWidget {
  final String taskId;

  const TaskStatusScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskStatusScreen> createState() => _TaskStatusScreenState();
}

class _TaskStatusScreenState extends ConsumerState<TaskStatusScreen> {
  // Константы для таймаутов и polling
  static const Duration _maxGenerationTime = Duration(minutes: 15);
  static const Duration _pollingInterval = Duration(seconds: 3);
  
  Timer? _pollingTimer;
  Timer? _timeUpdateTimer; // Таймер для обновления индикатора времени
  DateTime? _pollingStart;
  bool _isTimedOut = false;
  bool _isDisposed = false;
  
  BookGenerationStep? _lastStep;
  String? _lastStatus;
  bool _navigated = false;
  bool _lockUnlocked = false;
  String? _savedBookId; // Сохраняем book_id для продолжения генерации
  String? _savedChildId; // Сохраняем child_id для получения face_url и style

  @override
  void dispose() {
    _isDisposed = true;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _timeUpdateTimer?.cancel();
    _timeUpdateTimer = null;
    super.dispose();
  }

  void _startPolling() {
    if (_isDisposed) return;
    
    _pollingTimer?.cancel();
    _isTimedOut = false;
    _pollingStart = DateTime.now();
    _navigated = false;
    _lockUnlocked = false;

    _pollingTimer = Timer.periodic(_pollingInterval, (timer) {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }

      // Проверяем текущий статус задачи перед продолжением polling
      // Не продолжаем polling, если задача завершилась с ошибкой
      try {
        final currentTaskAsync = ref.read(taskStatusProvider(widget.taskId));
        if (currentTaskAsync.hasValue && currentTaskAsync.value != null) {
          final currentTask = currentTaskAsync.value!;
          // Не продолжаем polling, если задача завершилась с ошибкой
          if (currentTask.status == 'error' || currentTask.status == 'failed' || 
              (currentTask.error != null && currentTask.error!.isNotEmpty)) {
            timer.cancel();
            _timeUpdateTimer?.cancel();
            if (!_isDisposed && mounted) {
              _unlockGeneration();
            }
            return;
          }
        }
      } catch (e) {
        // Игнорируем ошибки при чтении статуса в polling
        // Продолжаем polling, если не можем прочитать статус
      }

      final elapsed = _pollingStart != null
          ? DateTime.now().difference(_pollingStart!)
          : Duration.zero;

      // Проверка таймаута (15 минут)
      if (elapsed > _maxGenerationTime) {
        timer.cancel();
        _timeUpdateTimer?.cancel();
        if (!_isDisposed && mounted) {
          setState(() {
            _isTimedOut = true;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_isDisposed && mounted) {
              _unlockGeneration();
            }
          });
        }
        return;
      }

      if (!_isDisposed && mounted) {
        ref.invalidate(taskStatusProvider(widget.taskId));
      }
    });
    
    // Запускаем таймер для обновления индикатора времени каждую секунду
    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }
      // Обновляем UI для показа времени
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _timeUpdateTimer?.cancel();
    _timeUpdateTimer = null;
  }

  void _unlockGeneration() {
    if (!_lockUnlocked && !_isDisposed && mounted) {
      _lockUnlocked = true;
      ref.read(generationLockProvider.notifier).state = false;
    }
  }

  void _handleTaskStateChange(TaskStatus? previous, TaskStatus current) {
    if (_isDisposed || !mounted) return;

    // ПРОВЕРКА 0: Задача потеряна (status='lost')
    if (current.isLost) {
      _stopPolling();
      // Сохраняем book_id из meta или progress для продолжения генерации
      final bookId = current.bookIdValue;
      if (bookId != null) {
        _savedBookId = bookId;
        // Получаем child_id из книги для получения face_url и style
        _loadBookInfoForContinue(bookId);
      }
      if (!_lockUnlocked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isDisposed && mounted) {
            _unlockGeneration();
          }
        });
      }
      return;
    }

    // ПРОВЕРКА 1: Ошибка в задаче
    // ВАЖНО: Проверяем error ПЕРЕД проверкой result
    // Если error !== null, считаем задачу завершенной с ошибкой
    if (current.error != null && current.error!.isNotEmpty) {
      // Задача завершена с ошибкой - останавливаем polling
      _stopPolling();
      // Сохраняем book_id если есть для возможности продолжения
      final bookId = current.bookIdValue;
      if (bookId != null) {
        _savedBookId = bookId;
      }
      if (!_lockUnlocked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isDisposed && mounted) {
            _unlockGeneration();
          }
        });
      }
      return;
    }

    // ПРОВЕРКА 2: Таймаут генерации
    if (_pollingStart != null) {
      final elapsed = DateTime.now().difference(_pollingStart!);
      final currentStatus = current.status;
      if (elapsed > _maxGenerationTime && currentStatus == 'running') {
        // Превышено время ожидания - останавливаем polling
        _stopPolling();
        if (!_lockUnlocked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_isDisposed && mounted) {
              setState(() {
                _isTimedOut = true;
              });
              _unlockGeneration();
            }
          });
        }
        return;
      }
    }

    final currentStep = current.generationStatus.step;
    final currentStatus = current.status;

    final stepChanged = _lastStep != currentStep;
    final statusChanged = _lastStatus != currentStatus;

    if (stepChanged) {
      _lastStep = currentStep;
    }
    if (statusChanged) {
      _lastStatus = currentStatus;
    }

    // При получении status: "error" сразу обновляем UI и останавливаем polling
    if (currentStatus == 'error' || currentStatus == 'failed') {
      _stopPolling();
      if (!_lockUnlocked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isDisposed && mounted) {
            _unlockGeneration();
          }
        });
      }
      return;
    }

    // Сохраняем book_id для возможного продолжения генерации
    final bookIdValue = current.bookIdValue;
    if (bookIdValue != null) {
      _savedBookId = bookIdValue;
    }
    
    // Переходим к книге сразу после получения book_id, даже если изображения еще не готовы
    // Это позволяет показывать книгу с placeholder для изображений
    if (bookIdValue != null && !_navigated) {
      // Проверяем, можно ли переходить к книге
      // Переходим если статус success/completed или если есть хотя бы текст (step >= text)
      final canNavigate = bookIdValue != null &&
                          (currentStatus == 'success' ||
                           currentStatus == 'completed' ||
                           currentStep == BookGenerationStep.done ||
                           currentStep == BookGenerationStep.text ||
                           currentStep == BookGenerationStep.prompts ||
                           currentStep == BookGenerationStep.draftImages ||
                           currentStep == BookGenerationStep.finalImages);
      
      if (canNavigate) {
      _stopPolling();
      _navigated = true;
      
      final bookId = bookIdValue;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isDisposed || !mounted || bookId == null) return;
          _unlockGeneration();
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!_isDisposed && mounted && bookId != null) {
              context.go(RouteNames.bookView.replaceAll(':id', bookId));
            }
          });
      });
      return;
    }
    }
  }

  void _handleRetry() {
    if (_isDisposed || !mounted) return;
    
    _navigated = false;
    _lockUnlocked = false;
    _isTimedOut = false;
    
    ref.read(generationLockProvider.notifier).state = true;
    
    Future.microtask(() {
      if (!_isDisposed && mounted) {
        _startPolling();
        ref.invalidate(taskStatusProvider(widget.taskId));
      }
    });
  }

  void _handleExit() {
    _stopPolling();
    _unlockGeneration();
    if (!_isDisposed && mounted) {
      context.go(RouteNames.books);
    }
  }

  /// Загрузить информацию о книге для продолжения генерации
  Future<void> _loadBookInfoForContinue(String bookId) async {
    try {
      final api = ref.read(backendApiProvider);
      final book = await api.getBook(bookId);
      _savedChildId = book.childId;
    } catch (e) {
      print('[TaskStatusScreen] Ошибка загрузки информации о книге: $e');
    }
  }

  /// Продолжить генерацию финальных изображений
  Future<void> _handleContinueGeneration() async {
    if (_savedBookId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Не удалось определить книгу для продолжения'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      // Получаем информацию о ребенке для face_url
      String? faceUrl;
      String? style;
      
      if (_savedChildId != null) {
        try {
          final api = ref.read(backendApiProvider);
          final children = await api.getChildren();
          final child = children.firstWhere(
            (c) => c.id == _savedChildId,
            orElse: () => throw Exception('Ребенок не найден'),
          );
          faceUrl = child.faceUrl;
          
          // Получаем книгу для определения стиля
          final book = await api.getBook(_savedBookId!);
          // Стиль можно получить из метаданных книги или использовать дефолтный
          // Пока используем дефолтный стиль 'disney'
          style = 'disney'; // TODO: получить из метаданных книги
        } catch (e) {
          print('[TaskStatusScreen] Ошибка получения данных ребенка: $e');
        }
      }

      if (faceUrl == null || faceUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Не удалось получить фото ребенка. Пожалуйста, обновите фото ребенка и попробуйте снова.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (style == null) {
        style = 'disney'; // Дефолтный стиль
      }

      // Показываем индикатор загрузки
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Продолжение генерации...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Вызываем API для продолжения генерации
      final api = ref.read(backendApiProvider);
      final response = await api.continueFinalImagesGeneration(
        bookId: _savedBookId!,
        faceUrl: faceUrl,
        style: style,
      );

      // Переходим к отслеживанию новой задачи
      if (mounted) {
        _navigated = false;
        _lockUnlocked = false;
        ref.read(generationLockProvider.notifier).state = true;
        
        // Переходим к экрану отслеживания новой задачи
        context.go(RouteNames.taskStatus.replaceAll(':id', response.taskId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при продолжении генерации: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  double _getProgress(TaskStatus task) {
    // Используем вычисленный прогресс из расширения (из current_step/total_steps)
    final calculatedProgress = task.generationStatus.progress;
    if (calculatedProgress != null && calculatedProgress >= 0 && calculatedProgress <= 100) {
      return calculatedProgress / 100; // Конвертируем из процентов в 0-1
    }
    
    // Fallback: используем этап генерации для приблизительного прогресса
    final step = task.generationStatus.step;
    switch (step) {
      case BookGenerationStep.profile:
        return 0.05;
      case BookGenerationStep.plot:
        return 0.1;
      case BookGenerationStep.text:
        return 0.2;
      case BookGenerationStep.prompts:
        return 0.35;
      case BookGenerationStep.draftImages:
        return 0.5;
      case BookGenerationStep.finalImages:
        return 0.8;
      case BookGenerationStep.done:
        return 1.0;
      default:
        return 0.1;
    }
  }
  
  String? _getDetailedProgressMessage(TaskStatus task) {
    final step = task.generationStatus.step;
    
    // Используем информацию о прогрессе изображений из TaskProgress
    if (step == BookGenerationStep.draftImages || step == BookGenerationStep.finalImages) {
      final progress = task.progress;
      if (progress?.imagesGenerated != null && progress?.totalImages != null) {
        final imagesGenerated = progress!.imagesGenerated!;
        final totalImages = progress.totalImages!;
        if (imagesGenerated > 0 && imagesGenerated < totalImages) {
          return 'Генерация изображения ${imagesGenerated + 1} из $totalImages';
        }
      }
      
      // Fallback: используем вычисленный прогресс
      final calculatedProgress = task.generationStatus.progress;
      if (calculatedProgress != null && calculatedProgress > 0 && calculatedProgress < 100) {
        // Приблизительно вычисляем количество изображений
        final totalImages = progress?.totalImages ?? 11; // По умолчанию 11 (1 обложка + 10 страниц)
        final progressValue = calculatedProgress / 100; // Конвертируем из процентов в 0-1
        final currentImage = ((progressValue * totalImages).ceil()).clamp(1, totalImages);
        return 'Генерация изображения $currentImage из $totalImages';
      }
    }
    
    return null;
  }

  String _getMinutesText(int minutes) {
    if (minutes == 1) return 'минута';
    if (minutes >= 2 && minutes <= 4) return 'минуты';
    return 'минут';
  }

  List<StepItem> _getSteps(TaskStatus task) {
    final step = task.generationStatus.step;
    final detailedProgress = _getDetailedProgressMessage(task);
    
    return [
      StepItem(
        title: 'Генерация текста',
        description: step == BookGenerationStep.text && detailedProgress == null
            ? 'Создаём историю...'
            : step == BookGenerationStep.text
                ? detailedProgress ?? 'Создаём историю...'
                : 'Создаём историю',
      ),
      StepItem(
        title: 'Создание изображений',
        description: (step == BookGenerationStep.draftImages || step == BookGenerationStep.finalImages) && detailedProgress != null
            ? detailedProgress!
            : step == BookGenerationStep.draftImages || step == BookGenerationStep.finalImages
                ? 'Рисуем иллюстрации...'
                : 'Рисуем иллюстрации',
      ),
      StepItem(
        title: 'Финальная обработка',
        description: step == BookGenerationStep.done
            ? 'Завершаем книгу...'
            : 'Завершаем книгу',
      ),
      StepItem(
        title: 'Готово',
        description: 'Книга создана!',
      ),
    ];
  }

  int _getCurrentStepIndex(TaskStatus task) {
    final step = task.generationStatus.step;
    switch (step) {
      case BookGenerationStep.profile:
      case BookGenerationStep.plot:
      case BookGenerationStep.text:
        return 0;
      case BookGenerationStep.prompts:
      case BookGenerationStep.draftImages:
      case BookGenerationStep.finalImages:
        return 1;
      case BookGenerationStep.done:
        return 2;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskStatusProvider(widget.taskId));

    ref.listen<AsyncValue<TaskStatus>>(
      taskStatusProvider(widget.taskId),
      (previous, next) {
        if (_isDisposed || !mounted) return;
        if (next.hasValue && next.value != null) {
          _handleTaskStateChange(
            previous?.value,
            next.value!,
          );
        }
      },
    );

    if (!_isDisposed && _pollingTimer == null && !_isTimedOut && !_navigated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed && mounted && _pollingTimer == null) {
          _startPolling();
        }
      });
    }

    // Timeout UI
    if (_isTimedOut) {
      return AppPage(
        backgroundImage: 'assets/logo/storyhero_bg_task_status.png',
        overlayOpacity: 0.2,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppAppBar(
            title: 'Создание книги',
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
                  context.go(RouteNames.books);
                }
              },
            ),
          ),
          body: Center(
            child: Padding(
              padding: AppSpacing.paddingMD,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AssetIcon(
                    assetPath: AppIcons.alert,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Превышено время ожидания',
                    style: safeCopyWith(
                      AppTypography.headlineMedium,
                      color: AppColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: AppSpacing.paddingMD,
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Генерация заняла слишком много времени (более 15 минут). Пожалуйста, попробуйте создать книгу снова.',
                      style: safeCopyWith(
                        AppTypography.bodyMedium,
                        color: AppColors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    text: 'Повторить',
                    onPressed: _handleRetry,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    text: 'Выйти',
                    outlined: true,
                    onPressed: _handleExit,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AppPage(
      backgroundImage: 'assets/logo/storyhero_bg_task_status.png',
      overlayOpacity: 0.2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppAppBar(
          title: 'Создание книги',
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
                context.go(RouteNames.books);
              }
            },
          ),
        ),
        body: taskAsync.when(
          data: (task) {
            // Pure UI rendering - no side effects
            if (task.status == 'completed' && task.bookIdValue != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.success, AppColors.success.withOpacity(0.7)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withOpacity(0.5),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: AssetIcon(
                        assetPath: AppIcons.success,
                        size: 60,
                        color: AppColors.onPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Книга создана!',
                      style: safeCopyWith(
                        AppTypography.headlineLarge,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Переходим к просмотру...',
                      style: safeCopyWith(
                        AppTypography.bodyLarge,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            // ПРОВЕРКА: Задача потеряна (status='lost')
            if (task.isLost) {
              return Center(
                child: Padding(
                  padding: AppSpacing.paddingMD,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AssetIcon(
                        assetPath: AppIcons.alert,
                        size: 64,
                        color: AppColors.warning,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Генерация была прервана',
                        style: safeCopyWith(
                          AppTypography.headlineMedium,
                          color: AppColors.warning,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: AppSpacing.paddingMD,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Генерация была прервана при перезапуске сервера. Книга готова для продолжения генерации финальных изображений.',
                          style: safeCopyWith(
                            AppTypography.bodyMedium,
                            color: AppColors.onBackground,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (_savedBookId != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        AppButton(
                          text: 'Продолжить генерацию',
                          onPressed: _handleContinueGeneration,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        text: 'Выйти',
                        outlined: true,
                        onPressed: _handleExit,
                      ),
                    ],
                  ),
                ),
              );
            }

            // ВАЖНО: Проверяем error ПЕРЕД проверкой result
            // Если error !== null, считаем задачу завершенной с ошибкой
            if (task.error != null && task.error!.isNotEmpty) {
              final errorMessage = task.error!.trim();
              String displayMessage;
              
              // Парсим сообщение об ошибке для разных типов ошибок
              if (errorMessage.contains('502') || 
                  errorMessage.contains('504') ||
                  errorMessage.contains('Pollinations.ai') ||
                  errorMessage.toLowerCase().contains('pollinations')) {
                displayMessage = 'Сервис генерации изображений временно недоступен. Попробуйте через несколько минут.';
              } else if (errorMessage.toLowerCase().contains('timeout') ||
                         errorMessage.toLowerCase().contains('таймаут') ||
                         errorMessage.toLowerCase().contains('превышено')) {
                displayMessage = 'Генерация заняла слишком много времени. Попробуйте создать книгу снова.';
              } else {
                // Показываем оригинальное сообщение от сервера
                displayMessage = errorMessage;
              }
              
              return Center(
                child: Padding(
                  padding: AppSpacing.paddingMD,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AssetIcon(
                        assetPath: AppIcons.alert,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Ошибка генерации',
                        style: safeCopyWith(
                          AppTypography.headlineMedium,
                          color: AppColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: AppSpacing.paddingMD,
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          displayMessage,
                          style: safeCopyWith(
                            AppTypography.bodyMedium,
                            color: AppColors.error,
                          ),
                        textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        text: 'Повторить',
                        onPressed: _handleRetry,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        text: 'Выйти',
                        outlined: true,
                        onPressed: _handleExit,
                      ),
                    ],
                  ),
                ),
              );
            }

            // Проверяем status: "error" или "failed"
            if (task.status == 'failed' || task.status == 'error') {
              final errorMessage = task.error?.trim();
              String displayMessage;
              
              if (errorMessage != null && errorMessage.isNotEmpty) {
                // Парсим сообщение об ошибке для 502/Pollinations.ai
                if (errorMessage.contains('502') || 
                    errorMessage.contains('Pollinations.ai') ||
                    errorMessage.toLowerCase().contains('pollinations')) {
                  displayMessage = 'Сервис генерации изображений временно недоступен. Попробуйте позже.';
                } else {
                  displayMessage = errorMessage;
                }
              } else {
                displayMessage = 'Произошла ошибка при генерации книги. Пожалуйста, попробуйте ещё раз.';
              }
              
              return Center(
                child: Padding(
                  padding: AppSpacing.paddingMD,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AssetIcon(
                        assetPath: AppIcons.alert,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Ошибка генерации',
                        style: safeCopyWith(
                          AppTypography.headlineMedium,
                          color: AppColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: AppSpacing.paddingMD,
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          displayMessage,
                          style: safeCopyWith(
                            AppTypography.bodyMedium,
                            color: AppColors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Если есть book_id, предлагаем продолжить генерацию
                      if (_savedBookId != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: AppSpacing.paddingMD,
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Книга была создана. Вы можете продолжить генерацию финальных изображений.',
                            style: safeCopyWith(
                              AppTypography.bodySmall,
                              color: AppColors.onBackground,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppButton(
                          text: 'Продолжить генерацию',
                          onPressed: _handleContinueGeneration,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        text: 'Повторить',
                        onPressed: _handleRetry,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        text: 'Выйти',
                        outlined: true,
                        onPressed: _handleExit,
                      ),
                    ],
                  ),
                ),
              );
            }

            // Running state - show progress
            final progress = _getProgress(task);
            final steps = _getSteps(task);
            final currentStepIndex = _getCurrentStepIndex(task);
            
            // Вычисляем прошедшее и оставшееся время
            final elapsed = _pollingStart != null
                ? DateTime.now().difference(_pollingStart!)
                : Duration.zero;
            final elapsedMinutes = elapsed.inMinutes;
            final estimatedTotalMinutes = 10;
            final remainingMinutes = (estimatedTotalMinutes - elapsedMinutes).clamp(0, estimatedTotalMinutes);

            return SingleChildScrollView(
              padding: AppSpacing.paddingMD,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Магическая Lottie анимация с процентами
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Lottie анимация на фоне
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: Lottie.asset(
                          'assets/animations/login_magic_swirl.json',
                          fit: BoxFit.contain,
                          repeat: true,
                        ),
                      ),
                      // Процент в центре анимации
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.3),
                              AppColors.primary.withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: safeCopyWith(
                                  AppTypography.headlineLarge,
                                  color: AppColors.onBackground,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 32.0,
                                ),
                              ),
                              Text(
                                'готово',
                                style: safeCopyWith(
                                  AppTypography.bodySmall,
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 12.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  Text(
                    'Создание вашей книги',
                    style: AppTypography.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  // Текущий этап с деталями
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.2),
                          AppColors.secondary.withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      task.generationStatus.step.displayName,
                      style: safeCopyWith(
                        AppTypography.bodyLarge,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  if (_getDetailedProgressMessage(task) != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _getDetailedProgressMessage(task)!,
                      style: safeCopyWith(
                        AppTypography.bodyMedium,
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Прогресс-бар
                  AppProgressBar(
                    progress: progress,
                    label: 'Генерация изображений: ${(progress * 100).toStringAsFixed(0)}%',
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Список этапов
                  AppStepList(
                    steps: steps,
                    currentStep: currentStepIndex,
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Индикатор времени
                  Container(
                    padding: AppSpacing.paddingSM,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                  Text(
                          'Генерация может занять до 10 минут',
                          style: safeCopyWith(
                            AppTypography.bodySmall,
                      color: AppColors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          elapsedMinutes > 0
                              ? 'Прошло: $elapsedMinutes ${_getMinutesText(elapsedMinutes)}${remainingMinutes > 0 ? ' • Осталось: ~$remainingMinutes ${_getMinutesText(remainingMinutes)}' : ''}'
                              : 'Начинаем генерацию...',
                          style: safeCopyWith(
                            AppTypography.bodyMedium,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Декоративные звёзды
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        child: AssetIcon(
                          assetPath: AppIcons.magicStar,
                          size: 24,
                          color: AppColors.accent.withOpacity(0.6),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
          loading: () => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppMagicLoader(size: 80),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Загрузка...',
                  style: AppTypography.bodyLarge,
                ),
              ],
            ),
          ),
          error: (error, stack) {
            // Pure UI - side effects handled in _handleExit
            return ErrorDisplayWidget(
              error: error,
              onRetry: _handleRetry,
              onExit: _handleExit,
            );
          },
        ),
      ),
    );
  }
}
