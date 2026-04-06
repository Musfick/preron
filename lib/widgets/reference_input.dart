// lib/widgets/reference_input.dart
import 'package:flutter/material.dart';

class ReferenceInput extends StatelessWidget {
  final String value;
  final String hintText;

  const ReferenceInput({
    super.key,
    required this.value,
    this.hintText = 'Enter Reference',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        value.isEmpty ? hintText : value.toUpperCase(),
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: value.isEmpty ? Colors.grey[400] : Colors.black87,
          letterSpacing: 3,
        ),
      ),
    );
  }
}