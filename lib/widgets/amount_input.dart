import 'package:flutter/material.dart';

class AmountInput extends StatelessWidget {
  final String value;
  final String prefixSymbol;
  final bool allowDecimal;
  final int maxDigits;

  const AmountInput({
    super.key,
    required this.value,
    this.prefixSymbol = '₹',
    this.allowDecimal = true,
    this.maxDigits = 10,
  });

  String _formatAmount(String value) {
    if (value.isEmpty) return '0';

    String cleanValue = value.replaceAll(RegExp(r'[^\d.]'), '');

    List<String> parts = cleanValue.split('.');
    String intPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '';

    if (intPart.length > maxDigits) {
      intPart = intPart.substring(0, maxDigits);
    }
    if (decimalPart.length > 2) {
      decimalPart = decimalPart.substring(0, 2);
    }

    intPart = _addCommas(intPart);

    if (decimalPart.isNotEmpty) return '$intPart.$decimalPart';
    if (value.endsWith('.')) return '$intPart.';  // ← preserve trailing dot
    return intPart;
  }


  String _addCommas(String value) {
    return value.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedValue = _formatAmount(value);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        '$prefixSymbol$formattedValue',
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}