import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

/// Custom numeric keypad for currency input.
/// Features:
/// - Number buttons 1-9, 0
/// - "000" quick-add button
/// - "," decimal comma button
/// - Backspace button
/// - Confirm (✓) button
/// - Live formatted display (e.g., Rp 3.000.000)
class CurrencyInputSheet extends StatefulWidget {
  final String? initialValue;
  final String title;
  final Color accentColor;

  const CurrencyInputSheet({
    super.key,
    this.initialValue,
    this.title = 'Masukkan Jumlah',
    this.accentColor = AppColors.primary,
  });

  @override
  State<CurrencyInputSheet> createState() => _CurrencyInputSheetState();
}

class _CurrencyInputSheetState extends State<CurrencyInputSheet> {
  String _rawInput = '';
  bool _hasDecimal = false;
  String _decimalPart = '';
  final _formatter = NumberFormat('#,##0', 'id_ID');

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      // Parse initial value - remove formatting
      String cleaned = widget.initialValue!.replaceAll('.', '');
      if (cleaned.contains(',')) {
        final parts = cleaned.split(',');
        _rawInput = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
        _decimalPart = parts.length > 1
            ? parts[1].replaceAll(RegExp(r'[^0-9]'), '')
            : '';
        _hasDecimal = true;
      } else {
        _rawInput = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
      }
    }
  }

  String get _displayText {
    if (_rawInput.isEmpty && !_hasDecimal) return '0';

    String formatted = '';
    if (_rawInput.isNotEmpty) {
      final intValue = int.tryParse(_rawInput) ?? 0;
      formatted = _formatter.format(intValue);
    } else {
      formatted = '0';
    }

    if (_hasDecimal) {
      formatted = '$formatted,$_decimalPart';
    }

    return formatted;
  }

  void _onNumberPress(String number) {
    setState(() {
      if (_hasDecimal) {
        if (_decimalPart.length < 2) {
          _decimalPart += number;
        }
      } else {
        // Prevent leading zeros
        if (_rawInput == '0' && number == '0') return;
        if (_rawInput == '0' && number != '0') {
          _rawInput = number;
        } else {
          // Max 15 digits
          if (_rawInput.length < 15) {
            _rawInput += number;
          }
        }
      }
    });
  }

  void _onTripleZero() {
    setState(() {
      if (_hasDecimal) return; // No 000 after decimal
      if (_rawInput.isEmpty || _rawInput == '0') {
        return; // Don't add 000 to empty/zero
      }
      if (_rawInput.length + 3 <= 15) {
        _rawInput += '000';
      }
    });
  }

  void _onDecimal() {
    setState(() {
      if (_hasDecimal) return; // Already has decimal
      _hasDecimal = true;
      if (_rawInput.isEmpty) _rawInput = '0';
    });
  }

  void _onBackspace() {
    setState(() {
      if (_hasDecimal) {
        if (_decimalPart.isNotEmpty) {
          _decimalPart = _decimalPart.substring(0, _decimalPart.length - 1);
        } else {
          _hasDecimal = false;
        }
      } else {
        if (_rawInput.isNotEmpty) {
          _rawInput = _rawInput.substring(0, _rawInput.length - 1);
        }
      }
    });
  }

  void _onClear() {
    setState(() {
      _rawInput = '';
      _hasDecimal = false;
      _decimalPart = '';
    });
  }

  void _onConfirm() {
    if (_rawInput.isEmpty && !_hasDecimal) {
      Navigator.pop(context, null);
      return;
    }
    Navigator.pop(context, _displayText);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),

          // Display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onLongPress: _onClear,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.accentColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rp ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: widget.accentColor.withValues(alpha: 0.6),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            _displayText,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: _rawInput.isEmpty && !_hasDecimal
                                  ? Colors.grey.shade400
                                  : AppColors.textDark,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (_rawInput.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Tekan lama untuk hapus semua',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Keypad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildKeypadRow(['1', '2', '3', 'backspace']),
                const SizedBox(height: 8),
                _buildKeypadRow(['4', '5', '6', ',']),
                const SizedBox(height: 8),
                _buildKeypadRow(['7', '8', '9', '000']),
                const SizedBox(height: 8),
                _buildKeypadRow(['', '0', '', 'confirm']),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      children: keys
          .map(
            (key) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildKey(key),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildKey(String key) {
    if (key.isEmpty) return const SizedBox(height: 56);

    final isBackspace = key == 'backspace';
    final isConfirm = key == 'confirm';
    final isTripleZero = key == '000';
    final isDecimal = key == ',';

    Color bgColor;
    Widget child;

    if (isConfirm) {
      bgColor = widget.accentColor;
      child = const Icon(Icons.check_rounded, color: Colors.white, size: 28);
    } else if (isBackspace) {
      bgColor = Colors.red.shade50;
      child = Icon(
        Icons.backspace_outlined,
        color: Colors.red.shade400,
        size: 22,
      );
    } else if (isTripleZero) {
      bgColor = widget.accentColor.withValues(alpha: 0.1);
      child = Text(
        '000',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: widget.accentColor,
        ),
      );
    } else if (isDecimal) {
      bgColor = Colors.grey.shade100;
      child = Text(
        ',',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: _hasDecimal ? Colors.grey.shade400 : AppColors.textDark,
        ),
      );
    } else {
      bgColor = Colors.grey.shade50;
      child = Text(
        key,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      );
    }

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (isConfirm) {
            _onConfirm();
          } else if (isBackspace) {
            _onBackspace();
          } else if (isTripleZero) {
            _onTripleZero();
          } else if (isDecimal) {
            _onDecimal();
          } else {
            _onNumberPress(key);
          }
        },
        onLongPress: isBackspace ? _onClear : null,
        child: Container(height: 56, alignment: Alignment.center, child: child),
      ),
    );
  }
}

/// Helper function to show the currency input sheet and return the formatted value
Future<String?> showCurrencyInput(
  BuildContext context, {
  String? initialValue,
  String title = 'Masukkan Jumlah',
  Color accentColor = AppColors.primary,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => CurrencyInputSheet(
      initialValue: initialValue,
      title: title,
      accentColor: accentColor,
    ),
  );
}
