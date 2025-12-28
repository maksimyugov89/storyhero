import 'package:flutter/material.dart';
import '../presentation/design_system/app_colors.dart';
import '../presentation/design_system/app_typography.dart';
import '../presentation/design_system/app_spacing.dart';
import '../utils/text_style_helpers.dart';

/// Виджет для ввода адреса с отдельными полями:
/// город, улица, дом (корпус), квартира, индекс
class AddressInputFields extends StatelessWidget {
  final TextEditingController cityController;
  final TextEditingController streetController;
  final TextEditingController houseController;
  final TextEditingController apartmentController;
  final TextEditingController postalCodeController;
  
  final String? Function(String?)? cityValidator;
  final String? Function(String?)? streetValidator;
  final String? Function(String?)? houseValidator;
  final String? Function(String?)? apartmentValidator;
  final String? Function(String?)? postalCodeValidator;
  
  final bool enabled;

  const AddressInputFields({
    super.key,
    required this.cityController,
    required this.streetController,
    required this.houseController,
    required this.apartmentController,
    required this.postalCodeController,
    this.cityValidator,
    this.streetValidator,
    this.houseValidator,
    this.apartmentValidator,
    this.postalCodeValidator,
    this.enabled = true,
  });

  /// Получить полный адрес в формате: город, улица, дом (корпус), квартира, индекс
  String getFullAddress() {
    final parts = <String>[];
    
    if (cityController.text.trim().isNotEmpty) {
      parts.add(cityController.text.trim());
    }
    if (streetController.text.trim().isNotEmpty) {
      parts.add(streetController.text.trim());
    }
    if (houseController.text.trim().isNotEmpty) {
      parts.add(houseController.text.trim());
    }
    if (apartmentController.text.trim().isNotEmpty) {
      parts.add('кв. ${apartmentController.text.trim()}');
    }
    if (postalCodeController.text.trim().isNotEmpty) {
      parts.add(postalCodeController.text.trim());
    }
    
    return parts.join(', ');
  }

  /// Проверить, что все обязательные поля заполнены
  bool validate() {
    return cityController.text.trim().isNotEmpty &&
           streetController.text.trim().isNotEmpty &&
           houseController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Адрес доставки',
          style: safeCopyWith(
            AppTypography.labelLarge,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        
        // Город
        TextFormField(
          controller: cityController,
          enabled: enabled,
          validator: cityValidator ?? _defaultValidator,
          decoration: _inputDecoration('Город', Icons.location_city_outlined),
          style: safeCopyWith(AppTypography.bodyLarge, color: AppColors.onSurface),
        ),
        const SizedBox(height: AppSpacing.md),
        
        // Улица
        TextFormField(
          controller: streetController,
          enabled: enabled,
          validator: streetValidator ?? _defaultValidator,
          decoration: _inputDecoration('Улица', Icons.streetview_outlined),
          style: safeCopyWith(AppTypography.bodyLarge, color: AppColors.onSurface),
        ),
        const SizedBox(height: AppSpacing.md),
        
        // Дом (корпус) и Квартира в одной строке
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: houseController,
                enabled: enabled,
                validator: houseValidator ?? _defaultValidator,
                decoration: _inputDecoration('Дом (корпус)', Icons.home_outlined),
                style: safeCopyWith(AppTypography.bodyLarge, color: AppColors.onSurface),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextFormField(
                controller: apartmentController,
                enabled: enabled,
                validator: apartmentValidator,
                decoration: _inputDecoration('Квартира', Icons.door_front_door_outlined),
                keyboardType: TextInputType.number,
                style: safeCopyWith(AppTypography.bodyLarge, color: AppColors.onSurface),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        
        // Индекс
        TextFormField(
          controller: postalCodeController,
          enabled: enabled,
          validator: postalCodeValidator,
          decoration: _inputDecoration('Индекс', Icons.markunread_mailbox_outlined),
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: safeCopyWith(AppTypography.bodyLarge, color: AppColors.onSurface),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
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
    );
  }

  String? _defaultValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обязательное поле';
    }
    return null;
  }
}

