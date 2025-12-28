import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../presentation/design_system/app_colors.dart';
import '../presentation/design_system/app_typography.dart';
import '../utils/text_style_helpers.dart';
import '../utils/phone_formatter.dart';

/// Поле ввода телефона с автоматическим форматированием +7 (XXX) XXX-XX-XX
class PhoneInputField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? Function(String?)? validator;
  final bool enabled;

  const PhoneInputField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      enabled: enabled,
      inputFormatters: [
        PhoneInputFormatter(),
        LengthLimitingTextInputFormatter(18), // +7 (XXX) XXX-XX-XX = 18 символов
      ],
      validator: validator ?? _defaultValidator,
      style: safeCopyWith(AppTypography.bodyLarge, color: AppColors.onSurface),
      decoration: InputDecoration(
        labelText: label ?? 'Телефон',
        hintText: hint ?? '+7 (XXX) XXX-XX-XX',
        prefixIcon: const Icon(Icons.phone_outlined),
        filled: true,
        fillColor: AppColors.surface.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
      ),
    );
  }

  String? _defaultValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите номер телефона';
    }
    if (!PhoneInputFormatter.isValid(value)) {
      return 'Введите корректный номер телефона';
    }
    return null;
  }
}

