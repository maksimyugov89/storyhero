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
  Timer? _pollingTimer;
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
    super.dispose();
  }

  void _startPolling() {
    if (_isDisposed) return;
    
    _pollingTimer?.cancel();
    _isTimedOut = false;
    _pollingStart = DateTime.now();
    _navigated = false;
    _lockUnlocked = false;

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }

      final elapsed = _pollingStart != null
          ? DateTime.now().difference(_pollingStart!)
          : Duration.zero;

      if (elapsed > const Duration(minutes: 7)) {
        timer.cancel();
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
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _unlockGeneration() {
    if (!_lockUnlocked && !_isDisposed && mounted) {
      _lockUnlocked = true;
      ref.read(generationLockProvider.notifier).state = false;
    }
  }

  void _handleTaskStateChange(TaskStatus? previous, TaskStatus current) {
    if (_isDisposed || !mounted) return;

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

    if ((currentStatus == 'completed' || currentStep == BookGenerationStep.done) && 
        current.bookId != null && 
        !_navigated) {
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

    if ((currentStatus == 'failed' || currentStatus == 'error') && !_lockUnlocked) {
      _stopPolling();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed && mounted) {
          _unlockGeneration();
        }
      });
      return;
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
          body: ErrorDisplayWidget(
            customMessage: 'Время ожидания генерации истекло. Попробуйте позже.',
            onRetry: _handleRetry,
            onExit: _handleExit,
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
                      style: AppTypography.headlineLarge.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Переходим к просмотру...',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (task.status == 'failed' || task.status == 'error') {
              final errorMessage = task.error?.trim();
              final displayMessage = errorMessage != null && errorMessage.isNotEmpty
                  ? errorMessage
                  : 'Произошла ошибка при генерации книги. Пожалуйста, попробуйте ещё раз.';
              
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
                        style: AppTypography.headlineMedium.copyWith(
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
                          style: AppTypography.bodyMedium.copyWith(
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
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  if (_getDetailedProgressMessage(task) != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _getDetailedProgressMessage(task)!,
                      style: AppTypography.bodyMedium.copyWith(
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
                  
                  // Оценка времени
                  Text(
                    'Примерно ${(7 - (DateTime.now().difference(_pollingStart ?? DateTime.now()).inMinutes)).clamp(0, 7)} минут',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
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
