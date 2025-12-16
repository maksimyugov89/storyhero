import 'package:flutter/material.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/app_radius.dart';
import '../../design_system/app_shadows.dart';
import '../../../../core/utils/text_style_helpers.dart';

/// Прогресс-бар с glow эффектом
class AppProgressBar extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final Color? color;
  final String? label;

  const AppProgressBar({
    super.key,
    required this.progress,
    this.color,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = color ?? AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: safeTextStyle(
              color: AppColors.onSurface,
              fontSize: 14.0,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppRadius.radiusFull,
          ),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: AppRadius.radiusFull,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                width: MediaQuery.of(context).size.width * progress,
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [progressColor, progressColor.withOpacity(0.7)],
                  ),
                  borderRadius: AppRadius.radiusFull,
                  boxShadow: AppShadows.glowPrimary(
                    opacity: 0.5,
                    blur: 10,
                    spread: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toInt()}%',
          style: safeTextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 12.0,
          ),
        ),
      ],
    );
  }
}









