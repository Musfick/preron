// lib/widgets/alphanumeric_keypad.dart
import 'package:flutter/material.dart';

class AlphanumericKeypad extends StatelessWidget {
  final Function(String) onKeyPressed;
  final bool showBackspace;

  const AlphanumericKeypad({
    super.key,
    required this.onKeyPressed,
    this.showBackspace = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Letters Row 1: Q-W-E-R-T-Y-U-I-O-P
        _buildKeyRow(['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P']),
        // Letters Row 2: A-S-D-F-G-H-J-K-L
        _buildKeyRow(['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L']),
        // Letters Row 3: Z-X-C-V-B-N-M
        _buildKeyRow(['Z', 'X', 'C', 'V', 'B', 'N', 'M']),
        // Numbers and Backspace
        _buildKeyRow(['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']),
        // Space and Backspace
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: InkWell(
                    onTap: () => onKeyPressed(' '),
                    borderRadius: BorderRadius.circular(8),
                    child: const Center(
                      child: Text(
                        'SPACE',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: InkWell(
                    onTap: showBackspace ? () => onKeyPressed('backspace') : null,
                    borderRadius: BorderRadius.circular(8),
                    child: const Center(
                      child: Icon(
                        Icons.backspace_outlined,
                        size: 28,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Expanded(
      child: Row(
        children: keys.map((key) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(6),
              ),
              child: InkWell(
                onTap: () => onKeyPressed(key),
                borderRadius: BorderRadius.circular(6),
                child: Center(
                  child: Text(
                    key,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}