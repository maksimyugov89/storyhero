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
  
  // State machine tracking
  BookGenerationStep? _lastStep;
  String? _lastStatus;
  bool _navigated = false;
  bool _lockUnlocked = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _isTimedOut = false;
    _pollingStart = DateTime.now();
    _navigated = false;
    _lockUnlocked = false;

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) {
        _pollingTimer?.cancel();
        return;
      }

      // Check timeout
      if (_pollingStart != null &&
          DateTime.now().difference(_pollingStart!) >
              const Duration(minutes: 7)) {
        _pollingTimer?.cancel();
        if (mounted) {
          setState(() {
            _isTimedOut = true;
          });
          // Schedule unlock after build completes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _unlockGeneration();
            }
          });
        }
        return;
      }

      // Invalidate provider to trigger refresh
      if (mounted) {
        ref.invalidate(taskStatusProvider(widget.taskId));
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _unlockGeneration() {
    if (!_lockUnlocked) {
      _lockUnlocked = true;
      ref.read(generationLockProvider.notifier).state = false;
    }
  }

  void _handleTaskStateChange(TaskStatus? previous, TaskStatus current) {
    if (!mounted) return;

    final currentStep = current.generationStatus.step;
    final currentStatus = current.status;

    // Detect state transitions
    final stepChanged = _lastStep != currentStep;
    final statusChanged = _lastStatus != currentStatus;

    if (stepChanged) {
      _lastStep = currentStep;
    }
    if (statusChanged) {
      _lastStatus = currentStatus;
    }

    // Handle completed state - check both status and step to prevent double navigation
    if ((currentStatus == 'completed' || currentStep == BookGenerationStep.done) && 
        current.bookId != null && 
        !_navigated) {
      _stopPolling();
      _navigated = true;
      
      // Store bookId locally to prevent null issues
      final bookId = current.bookId;
      
      // Schedule unlock and navigation after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && bookId != null) {
          _unlockGeneration();
          // Navigate after a short delay for UI feedback
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted && bookId != null) {
              context.go(RouteNames.bookView.replaceAll(':id', bookId));
            }
          });
        }
      });
      return;
    }

    // Handle failed/error state
    if ((currentStatus == 'failed' || currentStatus == 'error') && !_lockUnlocked) {
      _stopPolling();
      // Schedule unlock after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _unlockGeneration();
        }
      });
      return;
    }
  }

  void _handleRetry() {
    _navigated = false;
    _lockUnlocked = false;
    
    // Set lock first
    ref.read(generationLockProvider.notifier).state = true;
    
    // Schedule polling start and invalidation after lock is set
    Future.microtask(() {
      if (mounted) {
        _startPolling();
        ref.invalidate(taskStatusProvider(widget.taskId));
      }
    });
  }

  void _handleExit() {
    _stopPolling();
    _unlockGeneration();
    if (mounted) {
      context.go(RouteNames.books);
    }
  }

  double _getProgress(TaskStatus task) {
    final step = task.generationStatus.step;
    switch (step) {
      case BookGenerationStep.text:
        return 0.2;
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

  List<StepItem> _getSteps(TaskStatus task) {
    return [
      StepItem(
        title: 'Генерация текста',
        description: 'Создаём историю...',
      ),
      StepItem(
        title: 'Создание изображений',
        description: 'Рисуем иллюстрации...',
      ),
      StepItem(
        title: 'Финальная обработка',
        description: 'Завершаем книгу...',
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
      case BookGenerationStep.text:
        return 0;
      case BookGenerationStep.draftImages:
        return 1;
      case BookGenerationStep.finalImages:
        return 2;
      case BookGenerationStep.done:
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskStatusProvider(widget.taskId));

    // Listen to task changes for state machine
    ref.listen<AsyncValue<TaskStatus>>(
      taskStatusProvider(widget.taskId),
      (previous, next) {
        if (next.hasValue && next.value != null) {
          _handleTaskStateChange(
            previous?.value,
            next.value!,
          );
        }
      },
    );

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
                      Text(
                        task.error ?? 'Произошла ошибка',
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
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
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Прогресс-бар
                  AppProgressBar(
                    progress: progress,
                    label: 'Прогресс',
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
