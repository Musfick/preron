// lib/widgets/numeric_keypad.dart
import 'package:flutter/material.dart';

class NumericKeypad extends StatelessWidget {
  final Function(String) onKeyPressed;
  final bool showDecimal;
  final bool showBackspace;

  const NumericKeypad({
    super.key,
    required this.onKeyPressed,
    this.showDecimal = true,
    this.showBackspace = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _buildKeyRow(['1', '2', '3']),
          _buildKeyRow(['4', '5', '6']),
          _buildKeyRow(['7', '8', '9']),
          _buildKeyRow([
            if (showDecimal) '.' else '',
            '0',
            if (showBackspace) 'backspace' else ''
          ]),
        ],
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Expanded(
      child: Row(
        children: keys.map((key) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey.shade100,
                  width: 1.2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: key.isNotEmpty ? () => onKeyPressed(key) : null,
                  borderRadius: BorderRadius.circular(12),
                  splashColor: Colors.grey.shade200,
                  highlightColor: Colors.grey.shade100,
                  child: Center(
                    child: _buildKeyContent(key),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKeyContent(String key) {
    if (key == 'backspace') {
      return Icon(
        Icons.backspace_outlined,
        size: 28,
        color: Colors.grey.shade800, // Darker icon
      );
    }
    return Text(
      key,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w500,
        color: Colors.grey.shade800, // Darker text
      ),
    );
  }
}