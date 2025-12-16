import 'package:flutter/material.dart';
import '../../../ui/components/asset_icon.dart';

class TimelineStep extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isCompleted;
  final bool isActive;
  final int stepNumber;

  const TimelineStep({
    super.key,
    required this.title,
    this.subtitle,
    this.isCompleted = false,
    this.isActive = false,
    this.stepNumber = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = Theme.of(context).colorScheme.primary;
    final completedColor = activeColor;
    final inactiveColor = isDark
        ? Colors.white.withOpacity(0.3)
        : Colors.black.withOpacity(0.3);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Номер шага / индикатор
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted || isActive
                    ? completedColor
                    : inactiveColor,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: activeColor.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: isCompleted
                    ? AssetIcon(assetPath: AppIcons.success, size: 20, color: Colors.white)
                    : Text(
                        stepNumber.toString(),
                        style: TextStyle(
                          color: isActive || isCompleted
                              ? Colors.white
                              : inactiveColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 2,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      activeColor,
                      activeColor.withOpacity(0.3),
                    ],
                  ),
                ),
              )
            else if (!isCompleted)
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 2,
                height: 40,
                color: inactiveColor,
              ),
          ],
        ),
        const SizedBox(width: 16),
        // Текст шага
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: safeCopyWith(
                  Theme.of(context).textTheme.titleMedium,
                  fontSize: 18.0,
                  color: isCompleted || isActive
                      ? (isDark ? Colors.white : Colors.black87)
                      : inactiveColor,
                  fontWeight: isActive || isCompleted
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: safeCopyWith(
                    Theme.of(context).textTheme.bodySmall,
                    fontSize: 12.0,
                    color: isActive || isCompleted
                        ? (isDark ? Colors.white70 : Colors.black54)
                            : inactiveColor,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

