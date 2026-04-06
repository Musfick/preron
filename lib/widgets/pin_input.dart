import 'package:flutter/material.dart';

class PinInput extends StatelessWidget {
  final String value;
  final int pinLength;
  final bool obscureText;
  final String? hintText;

  const PinInput({
    super.key,
    required this.value,
    this.pinLength = 4,
    this.obscureText = true,
    this.hintText = 'Enter PIN',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: obscureText
          ? _buildDots()
          : _buildDigits(),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pinLength, (index) {
        final isFilled = index < value.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? Colors.black : Colors.grey[300],
          ),
        );
      }),
    );
  }

  Widget _buildDigits() {
    String displayValue = value.padRight(pinLength, '•');
    if (displayValue.length > pinLength) {
      displayValue = displayValue.substring(0, pinLength);
    }

    return Text(
      displayValue,
      style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
        letterSpacing: 12,
      ),
    );
  }
}