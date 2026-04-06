import 'package:flutter/material.dart';

class PermissionCard extends StatelessWidget {
  final String title;
  final IconData iconData;
  final bool isGranted;
  final bool isLoading;
  final VoidCallback onAction;
  final String actionText;

  const PermissionCard({
    super.key,
    required this.title,
    required this.isGranted,
    required this.isLoading,
    required this.onAction,
    required this.actionText, required this.iconData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isGranted ? Colors.green : Colors.black12,
            ),
            padding: EdgeInsets.all(8),
            child: Icon(
              iconData,
              color: isGranted ? Colors.white : Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  isGranted ? 'Enabled' : 'Not enabled',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isGranted ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (!isGranted)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              onPressed: onAction,
              child: Text(actionText),
            ),
        ],
      ),
    );
  }
}


class HomeAction extends StatelessWidget {
  final String title;
  final VoidCallback onAction;

  const HomeAction({super.key, required this.onAction, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onAction,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onAction,
                  icon: Icon(Icons.arrow_forward),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}