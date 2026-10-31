import 'dart:io' show File;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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

  static bool get _canInstallInApp =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
              // Android: download the new APK inside the app and open the
              // installer. Everything else (and any failure) falls back to
              // opening the release page, exactly like before.
              if (_canInstallInApp && context.mounted) {
                await showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => _ApkUpdateDialog(fallbackUrl: url),
                );
                return;
              }
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


// ── In-app APK download + install (Android) ──────────────────────────────────
//
// Finds the newest APK attached to the public GitHub release, downloads it
// with a progress bar, then hands it to Android's installer. Android always
// asks the user to confirm the install; it can never be fully silent.

class _ApkUpdateDialog extends StatefulWidget {
  final String fallbackUrl;
  const _ApkUpdateDialog({required this.fallbackUrl});

  @override
  State<_ApkUpdateDialog> createState() => _ApkUpdateDialogState();
}

class _ApkUpdateDialogState extends State<_ApkUpdateDialog> {
  static const _releaseApi =
      'https://api.github.com/repos/cs-bot24/cs-simplified-app/releases/latest';

  final CancelToken _cancel = CancelToken();
  double? _progress;
  String _status = 'Preparing download...';
  String? _error;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    if (!_cancel.isCancelled) _cancel.cancel();
    super.dispose();
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _installing = false;
    });
  }

  Future<void> _run() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 2),
      ));

      final rel = await dio.get<Map<String, dynamic>>(
        _releaseApi,
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
        cancelToken: _cancel,
      );
      final assets = (rel.data?['assets'] as List?) ?? const [];
      Map? apk;
      for (final a in assets) {
        if (a is Map &&
            ((a['name'] as String?) ?? '').toLowerCase().endsWith('.apk')) {
          apk = a;
          break;
        }
      }
      if (apk == null) {
        throw 'The new version is not ready to download yet.';
      }
      final url = apk['browser_download_url'] as String;
      final expected = (apk['size'] as num?)?.toInt() ?? 0;

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/cs-simplified-update.apk';

      if (!mounted) return;
      setState(() => _status = 'Downloading update...');
      await dio.download(
        url,
        path,
        cancelToken: _cancel,
        onReceiveProgress: (received, total) {
          final t = total > 0 ? total : expected;
          if (mounted && t > 0) {
            setState(() => _progress = (received / t).clamp(0.0, 1.0));
          }
        },
      );

      final length = await File(path).length();
      if (length < 1024 * 1024 || (expected > 0 && length != expected)) {
        throw 'The download was incomplete. Please try again.';
      }

      if (!mounted) return;
      setState(() {
        _status = 'Opening the installer...';
        _installing = true;
      });

      // Android 8+: the app must be allowed to install packages.
      var perm = await Permission.requestInstallPackages.status;
      if (!perm.isGranted) {
        perm = await Permission.requestInstallPackages.request();
      }
      if (!perm.isGranted) {
        throw 'Allow CS Simplified to install updates, then tap Update Now again.';
      }

      final res = await OpenFilex.open(
        path,
        type: 'application/vnd.android.package-archive',
      );
      if (res.type != ResultType.done) {
        throw 'Could not open the installer. ${res.message}';
      }
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      _fail('Download failed. Check your connection and try again.');
    } catch (e) {
      _fail(e is String ? e : 'The update could not be completed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = _progress == null ? null : (_progress! * 100).round();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Updating CS Simplified',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      content: _error != null
          ? Text(_error!)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_status),
                const SizedBox(height: 14),
                LinearProgressIndicator(value: _installing ? null : _progress),
                if (pct != null && !_installing) ...[
                  const SizedBox(height: 6),
                  Text('$pct%',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
      actions: [
        if (_error != null) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (widget.fallbackUrl.isNotEmpty)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await launchUrl(
                  Uri.parse(widget.fallbackUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text('Open download page'),
            ),
        ] else if (!_installing)
          TextButton(
            onPressed: () {
              _cancel.cancel();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
      ],
    );
  }
}
