import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';
import 'constants.dart';

class VersionCheck {
  static Future<void> check(BuildContext context) async {
    try {
      final data = await ApiClient.getVersion()
          .timeout(const Duration(seconds: 5));
      final latest = data['latest_version'] as String;
      final url    = data['download_url']   as String;
      if (!context.mounted) return;
      if (_isNewer(latest, AppConstants.appVersion)) {
        _showDialog(context, latest, url);
      }
    } catch (_) {}
  }

  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map(int.parse).toList();
    final c = current.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  static void _showDialog(BuildContext ctx, String version, String url) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.system_update_rounded, color: Color(0xFF1A3C6E)),
          SizedBox(width: 10),
          Text('Update Available'),
        ]),
        content: Text('Version $version is available.\n\nPlease update for the latest materials.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}
