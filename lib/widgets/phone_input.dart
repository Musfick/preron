import 'package:flutter/material.dart';

class PhoneInput extends StatelessWidget {
  final String value;
  final int maxLength;

  const PhoneInput({
    super.key,
    required this.value,
    this.maxLength = 11,
  });

  String _formatPhone(String value) {
    // Remove non-digit characters
    String cleanValue = value.replaceAll(RegExp(r'\D'), '');

    // Limit length
    if (cleanValue.length > maxLength) {
      cleanValue = cleanValue.substring(0, maxLength);
    }

    // Format: 017XX-XXXXXX (Bangladesh format)
    if (cleanValue.length > 5) {
      return '${cleanValue.substring(0, 4)}-${cleanValue.substring(4)}';
    }

    return cleanValue;
  }

  @override
  Widget build(BuildContext context) {
    String formattedValue = _formatPhone(value);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Text(
            formattedValue.isEmpty ? 'Enter Number' : formattedValue,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: formattedValue.isEmpty ? Colors.black26 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}