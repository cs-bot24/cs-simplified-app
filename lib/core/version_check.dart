import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';
import 'constants.dart';

class VersionCheck {
  /// Checks for updates.
  /// Returns true if an update is available and was shown to the user.
  /// Waits for the user to dismiss/act before returning — so the caller
  /// can safely navigate after this completes.
  static Future<bool> check(BuildContext context, {bool showNoUpdate = false}) async {
    try {
      final data   = await ApiClient.getVersion()
          .timeout(const Duration(seconds: 6));
      final latest = (data['latest_version'] as String?)?.trim() ?? '';
      final url    = (data['download_url']   as String?)?.trim() ?? '';

      if (latest.isEmpty) return false;
      if (!context.mounted) return false;

      if (_isNewer(latest, AppConstants.appVersion)) {
        // Wait for user to dismiss — this is the key fix.
        await _showUpdateDialog(context, latest, url);
        return true;
      } else {
        if (showNoUpdate && context.mounted) {
          await _showNoUpdateDialog(context);
        }
        return false;
      }
    } catch (e) {
      if (showNoUpdate && context.mounted) {
        _showErrorDialog(context);
      }
      return false;
    }
  }

  // ── Version comparison ─────────────────────────────────────────────────────

  static bool _isNewer(String latest, String current) {
    try {
      final l = latest.split('.').map(int.parse).toList();
      final c = current.split('.').map(int.parse).toList();
      // Pad to same length
      while (l.length < 3) l.add(0);
      while (c.length < 3) c.add(0);
      for (int i = 0; i < 3; i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  /// Shows update dialog and returns a Future that completes when dismissed.
  static Future<void> _showUpdateDialog(
      BuildContext context, String version, String url) {
    return showDialog<void>(
      context:            context,
      barrierDismissible: false, // force user to make a choice
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.system_update_rounded,
              color: Color(0xFF1A3C6E), size: 28),
          SizedBox(width: 10),
          Text('Update Available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Version $version is now available.',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          Text(
            'Update to get the latest materials, features, and improvements.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 14, color: Colors.blue),
              const SizedBox(width: 6),
              Text('Your version: ${AppConstants.appVersion}',
                  style: const TextStyle(fontSize: 12, color: Colors.blue)),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              if (url.isNotEmpty) {
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              }
            },
            icon: const Icon(Icons.download_rounded,
                color: Colors.white, size: 18),
            label: const Text('Update Now',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A3C6E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _showNoUpdateDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
          SizedBox(width: 10),
          Text('You\'re Up to Date',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'CS Simplified ${AppConstants.appVersion} is the latest version.',
          style: TextStyle(color: Colors.grey[600]),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Great!'),
          ),
        ],
      ),
    );
  }

  static void _showErrorDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Could not check for updates. Check your connection.'),
      behavior: SnackBarBehavior.floating,
    ));
  }
}
