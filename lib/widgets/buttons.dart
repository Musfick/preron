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
          textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14
          )
        ),
          onPressed: isLoading ? null : onPressed,
          child: isLoading ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.grey,
                  strokeWidth: 2.5,
                ),
              ),
              SizedBox(width: 16,),
              Text("Please wait..")
            ],
          ) : Text(text)
      ),
    );
  }
}
