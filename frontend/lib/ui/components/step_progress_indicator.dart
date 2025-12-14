import 'package:flutter/material.dart';
import '../../core/models/book_generation_step.dart';
import 'asset_icon.dart';

/// Индикатор прогресса этапов генерации книги
class StepProgressIndicator extends StatelessWidget {
  final BookGenerationStep step;
  final BookGenerationStep currentStep;
  final String title;
  final String? subtitle;

  const StepProgressIndicator({
    super.key,
    required this.step,
    required this.currentStep,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final stepIndex = step.index;
    final currentIndex = currentStep.index;
    
    final isCompleted = stepIndex < currentIndex;
    final isActive = stepIndex == currentIndex;
    final isPending = stepIndex > currentIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Индикатор статуса
          _buildStatusIndicator(context, isCompleted, isActive, isPending),
          const SizedBox(width: 16),
          // Текст
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: (Theme.of(context).textTheme.titleMedium ?? 
                          const TextStyle(fontSize: 18)).copyWith(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : isCompleted
                            ? Colors.green
                            : Colors.grey,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: (Theme.of(context).textTheme.bodySmall ?? 
                            const TextStyle(fontSize: 12)).copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(
    BuildContext context,
    bool isCompleted,
    bool isActive,
    bool isPending,
  ) {
    if (isCompleted) {
      // Зелёная галочка
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.green,
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.check,
          color: Colors.white,
          size: 20,
        ),
      );
    }

    if (isActive) {
      // Анимированный кружочек
      return SizedBox(
        width: 32,
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Внешний пульсирующий круг
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 1),
              builder: (context, value, child) {
                return Container(
                  width: 32 + (value * 8),
                  height: 32 + (value * 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2 * (1 - value)),
                  ),
                );
              },
              onEnd: () {
                // Перезапускаем анимацию
              },
            ),
            // Внутренний круг с индикатором загрузки
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Серый кружок для ожидающих этапов
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
        border: Border.all(
          color: Colors.grey[400]!,
          width: 2,
        ),
      ),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[500],
          ),
        ),
      ),
    );
  }
}

/// Виджет для отображения списка всех этапов
class StepProgressList extends StatelessWidget {
  final BookGenerationStep currentStep;
  final double? progress;

  const StepProgressList({
    super.key,
    required this.currentStep,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final allSteps = BookGenerationStep.values
        .where((step) => step != BookGenerationStep.done)
        .toList();

    return Column(
      children: [
        // Прогресс-бар сверху
        if (progress != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Общий прогресс',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${progress!.toInt()}%',
                      style: (Theme.of(context).textTheme.titleSmall ?? 
                              const TextStyle(fontSize: 16)).copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress! / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
        ],
        // Список этапов
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: allSteps.map((step) {
              return StepProgressIndicator(
                step: step,
                currentStep: currentStep,
                title: step.displayName,
                subtitle: step.description,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

