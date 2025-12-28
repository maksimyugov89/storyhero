import 'package:flutter/services.dart';

/// Форматтер для российского номера телефона: +7 (XXX) XXX-XX-XX
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    // Удаляем все символы, кроме цифр
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    
    // Если начинается не с 7 или 8, добавляем 7
    String formatted = digitsOnly;
    if (digitsOnly.isNotEmpty) {
      if (digitsOnly.startsWith('8')) {
        formatted = '7${digitsOnly.substring(1)}';
      } else if (!digitsOnly.startsWith('7')) {
        formatted = '7$digitsOnly';
      }
    }
    
    // Ограничиваем до 11 цифр (7 + 10 цифр)
    if (formatted.length > 11) {
      formatted = formatted.substring(0, 11);
    }
    
    // Форматируем: +7 (XXX) XXX-XX-XX
    String result = '';
    if (formatted.isNotEmpty && formatted.length >= 1) {
      result = '+7';
      if (formatted.length > 1) {
        // Код оператора (3 цифры после 7)
        final codeEnd = formatted.length > 4 ? 4 : formatted.length;
        final code = formatted.substring(1, codeEnd);
        result += ' ($code';
        
        if (formatted.length > 4) {
          result += ') ';
          // Первая часть номера (3 цифры)
          final part1End = formatted.length > 7 ? 7 : formatted.length;
          final part1 = formatted.substring(4, part1End);
          result += part1;
          
          if (formatted.length > 7) {
            result += '-';
            // Вторая часть номера (2 цифры)
            final part2End = formatted.length > 9 ? 9 : formatted.length;
            final part2 = formatted.substring(7, part2End);
            result += part2;
            
            if (formatted.length > 9) {
              result += '-';
              // Третья часть номера (2 цифры)
              final part3 = formatted.substring(9);
              result += part3;
            }
          }
        } else {
          result += ')';
        }
      }
    }
    
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
  
  /// Извлечь только цифры из отформатированного номера
  static String extractDigits(String formattedPhone) {
    return formattedPhone.replaceAll(RegExp(r'[^\d]'), '');
  }
  
  /// Проверить, что номер валидный (11 цифр, начинается с 7)
  static bool isValid(String formattedPhone) {
    final digits = extractDigits(formattedPhone);
    return digits.length == 11 && digits.startsWith('7');
  }
}

