// lib/screens/pdf/pdf_viewer_mobile.dart
//
// Mobile-only implementations used by pdf_viewer_screen.dart.
// All dart:io / Platform / Dio / Permission / path_provider usage is
// confined to this file so the web compiler never touches these symbols.
//
// Exports (must match pdf_viewer_web.dart stub signatures):
//   Widget  buildWebViewWidget(dynamic controller)
//   Future<void> downloadPdf({required String url, required String title,
//                              required void Function(double) onProgress,
//                              required void Function(String,{bool success}) onToast,
//                              required Future<void> Function(String path) onSaved})
//   WebViewControllerWrapper createWebViewController(String viewerUrl,
//                              {required void Function(bool loading) onLoadState,
//                               required void Function() onError})

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WebView
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps [WebViewController] so pdf_viewer_screen.dart never imports
/// webview_flutter directly (the type would be unresolved on web).
class WebViewControllerWrapper {
  final WebViewController controller;
  WebViewControllerWrapper(this.controller);
  void loadUrl(String url) => controller.loadRequest(Uri.parse(url));
}

/// Creates a ready-to-use [WebViewControllerWrapper].
WebViewControllerWrapper createWebViewController(
  String viewerUrl, {
  required void Function(bool loading) onLoadState,
  required void Function() onError,
}) {
  final ctrl = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(const Color(0xFF1A1A1A))
    ..setNavigationDelegate(NavigationDelegate(
      onPageStarted: (_) => onLoadState(true),
      onPageFinished: (_) => onLoadState(false),
      onWebResourceError: (e) {
        if (e.isForMainFrame ?? true) onError();
      },
    ))
    ..loadRequest(Uri.parse(viewerUrl));
  return WebViewControllerWrapper(ctrl);
}

/// Returns a [WebViewWidget] for mobile use.
Widget buildWebViewWidget(dynamic wrapper) {
  return WebViewWidget(
      controller: (wrapper as WebViewControllerWrapper).controller);
}

// ─────────────────────────────────────────────────────────────────────────────
// Download
// ─────────────────────────────────────────────────────────────────────────────

/// Self-contained PDF download using Dio.
/// All dart:io / Platform / Permission / path_provider access is here.
Future<void> downloadPdf({
  required String url,
  required String title,
  required void Function(double progress) onProgress,
  required void Function(String msg, {required bool success}) onToast,
  required Future<void> Function(String filePath) onSaved,
}) async {
  final rawUrl = url.trim();
  if (rawUrl.isEmpty) {
    onToast('No download URL.', success: false);
    return;
  }

  // Android < 10: request legacy storage permission
  if (Platform.isAndroid) {
    final sdk = await _androidSdkInt();
    if (sdk < 29) {
      final status = await Permission.storage.request();
      if (status.isDenied) {
        onToast('Storage permission denied.', success: false);
        return;
      }
    }
  }

  final saveDir = await _resolveDownloadsDirectory();
  final safeName = title
      .replaceAll(RegExp(r'[^\w\s\-]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  final destPath = '${saveDir.path}/$safeName.pdf';

  final dio = Dio();
  try {
    await dio.download(
      rawUrl,
      destPath,
      options: Options(
        headers: {'Accept': 'application/pdf,*/*'},
        followRedirects: true,
        receiveTimeout: const Duration(seconds: 120),
      ),
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress(received / total);
      },
    );
    onToast('Saved to Downloads ✓', success: true);
    await onSaved(destPath);
  } on DioException catch (e) {
    final reason = (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout)
        ? 'Connection timed out.'
        : e.type == DioExceptionType.badResponse
            ? 'Server error ${e.response?.statusCode}.'
            : 'Network error. Check your connection.';
    onToast(reason, success: false);
  } on FileSystemException catch (e) {
    onToast('Could not save file: ${e.message}', success: false);
  } catch (_) {
    onToast('Download failed.', success: false);
  } finally {
    dio.close();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helpers
// ─────────────────────────────────────────────────────────────────────────────

Future<Directory> _resolveDownloadsDirectory() async {
  if (Platform.isAndroid) {
    try {
      final dl = await getDownloadsDirectory();
      if (dl != null) {
        if (!await dl.exists()) await dl.create(recursive: true);
        return dl;
      }
    } catch (_) {}
    for (final path in [
      '/storage/emulated/0/Downloads',
      '/storage/emulated/0/Download',
    ]) {
      try {
        final dir = Directory(path);
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      } catch (_) {}
    }
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        if (!await ext.exists()) await ext.create(recursive: true);
        return ext;
      }
    } catch (_) {}
  }
  return getApplicationDocumentsDirectory();
}

Future<int> _androidSdkInt() async {
  try {
    final version = Platform.operatingSystemVersion;
    final match = RegExp(r'(?:SDK\s*|API\s*)(\d+)').firstMatch(version);
    if (match != null) return int.parse(match.group(1)!);
  } catch (_) {}
  return 33;
}
