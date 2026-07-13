import 'package:flutter/material.dart';

import '../core/connectivity_service.dart';

/// Full-screen "this needs an internet connection" state — for screens
/// that are inherently online-only (AI Tutor, Mock Exam, etc.) and have
/// nothing useful to show without a network.
class RequiresInternetView extends StatelessWidget {
  final String featureName;
  final VoidCallback? onRetry;

  const RequiresInternetView({
    super.key,
    required this.featureName,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text('No Internet Connection',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            '$featureName needs an internet connection. Downloaded materials are still available in your Offline Library.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.5),
          ),
          const SizedBox(height: 24),
          if (onRetry != null)
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
            ),
        ]),
      ),
    );
  }
}

/// A slim inline banner (not full-screen) for a section of a screen that's
/// unavailable offline while the rest of the screen still works — e.g. a
/// "Trending" section on a page that otherwise shows cached data.
class RequiresInternetInlineBanner extends StatelessWidget {
  final String message;
  const RequiresInternetInlineBanner({super.key, this.message = 'Some content needs an internet connection.'});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(Icons.wifi_off_rounded, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
      ]),
    );
  }
}

/// Gate for tapping into an online-only destination (AI Tutor, Exam Prep,
/// Leaderboard, etc.) from anywhere — bottom nav, home cards, buttons.
///
/// If online, runs [onProceed] immediately (e.g. `Navigator.push(...)`).
/// If offline, shows a friendly bottom sheet instead of letting the user
/// navigate into a screen that can only spin or error.
Future<void> requireInternet(
  BuildContext context, {
  required String featureName,
  required VoidCallback onProceed,
}) async {
  if (ConnectivityService.instance.isOnline) {
    onProceed();
    return;
  }

  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 44, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('$featureName Needs Internet',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Connect to the internet to use $featureName. Your downloaded materials are still available in the Offline Library.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final backOnline = await ConnectivityService.instance.checkNow();
                if (ctx.mounted) Navigator.pop(ctx);
                if (backOnline) onProceed();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ]),
      ),
    ),
  );
}
