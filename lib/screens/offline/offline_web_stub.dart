// lib/screens/offline/offline_web_stub.dart
//
// Shown on web when the Offline feature is accessed.
// Offline downloads require filesystem access which is not available in browsers.
// This stub keeps the web build clean and informs the user clearly.

import 'package:flutter/material.dart';

class OfflineWebStub extends StatelessWidget {
  const OfflineWebStub({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_for_offline_outlined,
              size: 64,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            const SizedBox(height: 20),
            const Text(
              'Offline Downloads',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Offline downloads are available on the\n'
              'CS Simplified Android app.\n\n'
              'Download the app to save materials\nand study without internet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: null,   // TODO: link to Play Store listing
              icon: const Icon(Icons.android_rounded),
              label: const Text('Get the Android App'),
            ),
          ],
        ),
      ),
    );
  }
}
