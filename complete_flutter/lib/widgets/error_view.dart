import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 15)),
        if (onRetry != null) ...[
          const SizedBox(height: 20),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ]),
    ),
  );
}
