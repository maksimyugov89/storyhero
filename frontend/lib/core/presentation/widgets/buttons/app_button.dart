import 'package:flutter/material.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/app_radius.dart';
import '../../design_system/app_spacing.dart';

/// Стандартная кнопка Material 3
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool fullWidth;
  final IconData? icon;
  final String? iconAsset;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.outlined = false,
    this.fullWidth = false,
    this.icon,
    this.iconAsset,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = outlined
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              padding: AppSpacing.paddingHMD + AppSpacing.paddingVMD,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.radiusMD,
              ),
              side: BorderSide(
                color: foregroundColor ?? AppColors.primary,
              ),
            ),
            child: _buildContent(context),
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              padding: AppSpacing.paddingHMD + AppSpacing.paddingVMD,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.radiusMD,
              ),
              backgroundColor: backgroundColor ?? AppColors.primary,
              foregroundColor: foregroundColor ?? AppColors.onPrimary,
              elevation: 0,
            ),
            child: _buildContent(context),
          );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }

  Widget _buildContent(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            foregroundColor ?? AppColors.onPrimary,
          ),
        ),
      );
    }

    final children = <Widget>[];

    if (icon != null) {
      children.add(Icon(icon, size: 20));
      children.add(const SizedBox(width: AppSpacing.sm));
    } else if (iconAsset != null) {
      children.add(
        Image.asset(
          iconAsset!,
          width: 20,
          height: 20,
        ),
      );
      children.add(const SizedBox(width: AppSpacing.sm));
    }

    children.add(Text(text));

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }
}









