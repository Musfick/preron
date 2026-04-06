import 'package:flutter/material.dart';

class PreronButton extends StatelessWidget {

  final Function()? onPressed;
  final String text;
  final bool isLoading;

  const PreronButton({
    super.key, required this.onPressed, required this.text, this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          textStyle: Theme.of(context).textTheme.bodyLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8))
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16
          )
        ),
          onPressed: onPressed,
          child: isLoading ? SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ) : Text(text)
      ),
    );
  }
}
