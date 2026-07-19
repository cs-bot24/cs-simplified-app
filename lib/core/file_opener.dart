// file_opener.dart
//
// Opens Office files (PPT/PPTX/DOC/DOCX) on the device's native app.
//
// Study tracking (unified with PDF):
//   1. Calls recordMaterialView immediately → updates Continue Reading.
//   2. Records _sessionStart timestamp before handing off to external app.
//   3. On app resume (via WidgetsBindingObserver in the CALLER), call
//      FileOpener.onAppResumed(materialId) which computes elapsed time
//      and sends study-ping if >= 3 minutes.
//
// The caller (MaterialsScreen / MaterialCard) must:
//   - mix in WidgetsBindingObserver
//   - call WidgetsBinding.instance.addObserver(this)
//   - override didChangeAppLifecycleState and call FileOpener.onAppResumed

import 'dart:developer' as dev;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/home_provider.dart';
import 'api_client.dart';

class FileOpener {
  // ── Singleton study-session state ─────────────────────────────────────────
  static int?      _pendingMaterialId;
  static DateTime? _sessionStart;
  static bool      _pingSent = false;

  static const int _minStudyMinutes = 3;

  /// Call this from WidgetsBindingObserver.didChangeAppLifecycleState
  /// in the screen that opened the file.
  static Future<void> onAppResumed(BuildContext context) async {
    if (_pendingMaterialId == null || _sessionStart == null || _pingSent) return;

    final elapsed = DateTime.now().difference(_sessionStart!);
    dev.log('[FileOpener] app resumed after ${elapsed.inSeconds}s for '
        'material $_pendingMaterialId');

    if (elapsed.inMinutes >= _minStudyMinutes) {
      _pingSent = true;
      try {
        final result = await ApiClient.studyPing(_pendingMaterialId!);
        final current = result['current_streak'] as int? ?? 0;
        dev.log('[FileOpener] study-ping sent, streak=$current');

        // Refresh home so Continue Reading and streak badge update
        if (context.mounted) {
          context.read<HomeProvider>().fetchHome(forceRefresh: true);
        }
      } catch (e) {
        dev.log('[FileOpener] study-ping error: $e');
      }
    }

    // Clear session — one ping per open session
    _pendingMaterialId = null;
    _sessionStart      = null;
  }

  /// Clear any pending session (call when screen disposes).
  static void clearSession() {
    _pendingMaterialId = null;
    _sessionStart      = null;
    _pingSent          = false;
  }

  /// Open a non-PDF file externally.
  /// Records view + starts study timer before handing off.
  static Future<void> openExternal({
    required BuildContext context,
    required String url,
    required String title,
    required String fileType,
    int? materialId,
  }) async {
    // 1. Record view immediately (Continue Reading + analytics)
    if (materialId != null) {
      try { ApiClient.recordMaterialView(materialId); } catch (_) {}
    }

    // 2. Show loading dialog while downloading
    if (!context.mounted) return;
    showDialog(
      context:             context,
      barrierDismissible:  false,
      builder:             (_) => const _LoadingDialog(),
    );

    try {
      final tempDir  = await getTemporaryDirectory();
      final safeName = title.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final filePath = '${tempDir.path}/$safeName.$fileType';

      // Only re-download if the file doesn't already exist
      if (!File(filePath).existsSync()) {
        await Dio().download(url, filePath);
      }

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      // 3. Start study session timer BEFORE opening external app
      if (materialId != null) {
        _pendingMaterialId = materialId;
        _sessionStart      = DateTime.now();
        _pingSent          = false;
        dev.log('[FileOpener] session started for material $materialId');
      }

      // 4. Open with device app
      final opened = await _openWithSystemApp(filePath);

      if (!opened && context.mounted) {
        _showError(context, fileType);
        // Clear session since file didn't open
        clearSession();
      }
    } on PlatformException catch (e) {
      dev.log('[FileOpener] PlatformException: $e');
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showError(context, fileType, detail: e.message);
      }
      clearSession();
    } catch (e) {
      dev.log('[FileOpener] Error: $e');
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showError(context, fileType, detail: e.toString());
      }
      clearSession();
    }
  }

  /// Opens [filePath] in the OS's default app for its file type.
  ///
  /// `open_filex` has no Windows implementation (desktop audit Part 3B) —
  /// on Windows this hands off to `url_launcher`'s `launchUrl(Uri.file(...))`
  /// instead, which already ships as a project dependency and does have
  /// Windows support. Android/iOS/macOS/Linux behavior is completely
  /// unchanged — they still go through `open_filex` exactly as before.
  static Future<bool> _openWithSystemApp(String filePath) async {
    if (Platform.isWindows) {
      try {
        return await launchUrl(Uri.file(filePath));
      } catch (e) {
        dev.log('[FileOpener] Windows launchUrl error: $e');
        return false;
      }
    }
    final result = await OpenFilex.open(filePath);
    return result.type == ResultType.done;
  }

  static void _showError(BuildContext context, String fileType, {String? detail}) {
    final isPpt = fileType == 'ppt' || fileType == 'pptx';
    final msg = isPpt
        ? 'No PowerPoint-compatible application found on this device.\n'
          'Please install Microsoft PowerPoint, WPS Office, or Google Slides.'
        : 'No document viewer found on this device.\n'
          'Please install Microsoft Word, WPS Office, or Google Docs.';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Cannot Open File'),
        content: Text(detail != null ? '$msg\n\n($detail)' : msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:     const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();
  @override
  Widget build(BuildContext context) => const AlertDialog(
    content: Row(children: [
      CircularProgressIndicator(),
      SizedBox(width: 20),
      Expanded(child: Text('Preparing file...')),
    ]),
  );
}
