import 'package:flutter/material.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/app_typography.dart';
import '../../design_system/app_spacing.dart';
import '../../../../ui/components/asset_icon.dart';

/// Список этапов с иконками статуса
class AppStepList extends StatelessWidget {
  final List<StepItem> steps;
  final int currentStep;

  const AppStepList({
    super.key,
    required this.steps,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isCompleted = index < currentStep;
        final isCurrent = index == currentStep;

        return Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? AppColors.success
                      : isCurrent
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                ),
                child: isCompleted
                    ? AssetIcon(
                        assetPath: AppIcons.success,
                        size: 20,
                        color: AppColors.onPrimary,
                      )
                    : isCurrent
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.onPrimary,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.circle_outlined,
                            size: 20,
                            color: AppColors.onSurfaceVariant,
                          ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: isCurrent || isCompleted
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isCompleted || isCurrent
                            ? AppColors.onSurface
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                    if (step.description != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        step.description!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class StepItem {
  final String title;
  final String? description;

  StepItem({
    required this.title,
    this.description,
  });
}

