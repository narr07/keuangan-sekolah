import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Custom Indonesian currency formatter.
/// Input: raw digits → Display: 3.000.000 (dot as thousands separator)
/// Supports decimal comma: 3.000.000,50
class IndonesianCurrencyFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat('#,##0', 'id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow empty
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove all dots (thousands separator) to get raw input
    String cleaned = newValue.text.replaceAll('.', '');

    // Handle comma as decimal separator
    final parts = cleaned.split(',');
    String integerPart = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
    String? decimalPart = parts.length > 1
        ? parts[1].replaceAll(RegExp(r'[^0-9]'), '')
        : null;

    if (integerPart.isEmpty && decimalPart == null) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Format integer part with dots as thousands separator
    String formatted = '';
    if (integerPart.isNotEmpty) {
      final intValue = int.tryParse(integerPart) ?? 0;
      formatted = _formatter.format(intValue);
    }

    // Append decimal part if exists
    if (decimalPart != null) {
      formatted = '$formatted,$decimalPart';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Parse formatted text back to double
  /// "3.000.000" → 3000000.0
  /// "3.000.000,50" → 3000000.50
  static double parse(String text) {
    if (text.isEmpty) return 0;
    // Remove dots (thousands separator)
    String cleaned = text.replaceAll('.', '');
    // Replace comma (decimal separator) with dot for parsing
    cleaned = cleaned.replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }
}
