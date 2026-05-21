import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'constants.dart';
import 'package:url_launcher/url_launcher.dart';


class VersionCheck {
  static Future<void> check(BuildContext context) async {
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/version'),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      final latestVersion = data['latest_version'] as String;
      final downloadUrl   = data['download_url']   as String;

      if (!context.mounted) return;

      // Compare versions
      if (_isNewer(latestVersion, AppConstants.appVersion)) {
        _showUpdateDialog(context, latestVersion, downloadUrl);
      }
    } catch (_) {
      // Silently fail — don't crash app if version check fails
    }
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

  static void _showUpdateDialog(
      BuildContext context, String version, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.system_update_rounded, color: Color(0xFF1A3C6E)),
            SizedBox(width: 10),
            Text('Update Available'),
          ],
        ),
        content: Text(
          'Version $version is available.\n\n'
          'Please update to get the latest materials and improvements.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Open download URL
              final uri = Uri.parse(url);
              await launchUrl(uri,
                  mode: LaunchMode.externalApplication);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A3C6E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Update Now',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}