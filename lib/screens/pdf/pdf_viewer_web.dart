// lib/screens/pdf/pdf_viewer_web.dart
//
// Web stubs that match every symbol exported by pdf_viewer_mobile.dart.
// The Flutter web compiler resolves imports to THIS file via:
//   import 'pdf_viewer_mobile.dart' if (dart.library.html) 'pdf_viewer_web.dart';
//
// None of dart:io, Platform, Dio, Permission, or path_provider is referenced.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WebView stubs — never rendered on web (kIsWeb guards all call sites)
// ─────────────────────────────────────────────────────────────────────────────

class WebViewControllerWrapper {
  // Opaque stub — web code never constructs or uses this.
  void loadUrl(String url) {}
}

WebViewControllerWrapper createWebViewController(
  String viewerUrl, {
  required void Function(bool loading) onLoadState,
  required void Function() onError,
}) {
  return WebViewControllerWrapper();
}

/// Never reached on web — _buildMobileLayout() is only called when !kIsWeb.
Widget buildWebViewWidget(dynamic wrapper) => const SizedBox.shrink();

// ─────────────────────────────────────────────────────────────────────────────
// Download — delegate to browser
// ─────────────────────────────────────────────────────────────────────────────

Future<void> downloadPdf({
  required String url,
  required String title,
  required void Function(double progress) onProgress,
  required void Function(String msg, {required bool success}) onToast,
  required Future<void> Function(String filePath) onSaved,
}) async {
  try {
    await launchUrl(
      Uri.parse(url.trim()),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    onToast('Could not open download.', success: false);
  }
}
