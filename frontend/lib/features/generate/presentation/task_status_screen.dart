import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes/route_names.dart';
import '../../../../core/api/backend_api.dart';
import '../../../../core/models/task_status.dart';
import '../../../../core/models/book_generation_step.dart';
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
import '../../../../app/routes/route_names.dart';

final taskStatusProvider = FutureProvider.family<TaskStatus, String>(
  (ref, taskId) async {
    final api = ref.watch(backendApiProvider);
    return await api.checkTaskStatus(taskId);
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

    // ПРОВЕРКА 1: Ошибка в задаче
    // ВАЖНО: Проверяем error ПЕРЕД проверкой result
    // Если error !== null, считаем задачу завершенной с ошибкой
    if (current.error != null && current.error!.isNotEmpty) {
      // Задача завершена с ошибкой - останавливаем polling
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

    // Переходим к книге сразу после получения book_id, даже если изображения еще не готовы
    // Это позволяет показывать книгу с placeholder для изображений
    if (current.bookId != null && !_navigated) {
      // Проверяем, можно ли переходить к книге
      // Переходим если статус success/completed или если есть хотя бы текст (step >= text)
      final canNavigate = current.bookId != null &&
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
      
      final bookId = current.bookId;
      
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

  double _getProgress(TaskStatus task) {
    if (task.progress != null && task.progress! >= 0 && task.progress! <= 1) {
      return task.progress!;
    }
    
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
    final progress = task.progress;
    
    if (progress != null && progress > 0 && progress < 1) {
      if (step == BookGenerationStep.draftImages || step == BookGenerationStep.finalImages) {
        final totalImages = 4;
        final currentImage = ((progress * totalImages).ceil()).clamp(1, totalImages);
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
            if (task.status == 'completed' && task.bookId != null) {
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
                  const SizedBox(height: AppSpacing.xxl),
                  
                  // Магическая анимация
                  AppMagicLoader(
                    size: 80,
                    glowColor: AppColors.primary,
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  Text(
                    'Создание вашей книги',
                    style: AppTypography.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  // Текущий этап с деталями
                  Text(
                    task.generationStatus.step.displayName,
                    style: safeCopyWith(
                      AppTypography.bodyLarge,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
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
                    label: 'Прогресс: ${(progress * 100).toStringAsFixed(0)}%',
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
