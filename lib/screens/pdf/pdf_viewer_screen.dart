// ============================================================
//  pdf_viewer_screen.dart
//
//  ARCHITECTURE CHANGE (May 2026):
//    OLD → syncfusion_flutter_pdfviewer (native renderer, unstable)
//    NEW → webview_flutter + Google Drive Viewer URL
//
//  Why this approach is more stable:
//    • No native PDF codec to crash on malformed PDFs.
//    • Google Drive Viewer handles rendering server-side, so the
//      app only renders an HTML page — a problem set WebView
//      solves extremely reliably on all Android versions.
//    • Zero licensing concerns (Syncfusion requires a paid licence
//      for commercial use beyond its free-tier limits).
//    • Cloudinary raw/upload URLs work without any auth header.
//
//  Screen contract (unchanged for callers):
//    PdfViewerScreen(url: String, title: String)
// ============================================================

import 'dart:developer' as dev;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/api_client.dart';
import '../../models/offline_material.dart';
import '../../models/rating_model.dart';
import '../../providers/offline_provider.dart';
import '../../widgets/rating_dialog.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  /// Optional material ID used to record a view event for the
  /// "Continue Reading" (recently viewed) feature.
  /// If null, no view is recorded (e.g. admin previewing a PDF).
  final int? materialId;

  const PdfViewerScreen({
    super.key,
    required this.url,
    required this.title,
    this.materialId,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  // ── WebView controller ────────────────────────────────────────────────────
  late final WebViewController _webController;

  // ── Dio for direct HTTP download (viewer uses WebView, not Dio) ──────────
  final Dio _dio = Dio();

  // ── UI state ──────────────────────────────────────────────────────────────
  bool _isLoading = true;
  bool _hasError = false;

  // ── Download state ────────────────────────────────────────────────────────
  bool _isDownloading = false;
  double _downloadProgress = 0;

  // ── Rating state (Phase 1.5B) ─────────────────────────────────────────────
  // Tracks how long the student has had the PDF open.
  // If > 10 seconds when they close, the rating dialog is shown.
  final Stopwatch _stopwatch = Stopwatch();
  // The student's existing rating (null = never rated).
  // Fetched silently in initState to pre-populate the dialog.
  RatingModel? _rating;

  // ── Google Drive Viewer URL ───────────────────────────────────────────────
  // The trick: Drive's /viewerng/viewer endpoint accepts any public PDF URL
  // via the `url=` query parameter. It renders the PDF server-side and
  // delivers an interactive HTML viewer inside the WebView.
  // URL-encoding the PDF link is mandatory — raw `&` in the PDF URL would
  // break the outer query string.
  String get _viewerUrl {
    final encoded = Uri.encodeComponent(widget.url.trim());
    return 'https://drive.google.com/viewerng/viewer?embedded=true&url=$encoded';
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initWebView();
    _stopwatch.start();

    if (widget.materialId != null) {
      // Record view for "Continue Reading" — fire-and-forget
      ApiClient.recordMaterialView(widget.materialId!);
      // Pre-fetch rating so dialog knows if student already rated
      _fetchRating();
    }
  }

  Future<void> _fetchRating() async {
    try {
      final raw = await ApiClient.getMaterialRating(widget.materialId!);
      if (mounted) {
        setState(() => _rating = RatingModel.fromJson(
            raw as Map<String, dynamic>));
      }
    } catch (_) {
      // Silent — rating fetch never interrupts the viewer
    }
  }

  /// Called when the student tries to close the screen.
  /// Shows the rating dialog if they've been reading for > 10 seconds.
  Future<void> _handleClose() async {
    _stopwatch.stop();
    if (widget.materialId != null &&
        _stopwatch.elapsed.inSeconds >= 10 &&
        mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => RatingDialog(
          existingRating: _rating?.userRating,
          onSubmit: (stars) async {
            await ApiClient.rateMaterial(widget.materialId!, stars);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(children: [
                    Icon(Icons.star_rounded,
                        color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('Thank you for rating!'),
                  ]),
                  backgroundColor: Colors.amber[700],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          },
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  // ── WebView initialisation ────────────────────────────────────────────────

  void _initWebView() {
    _webController = WebViewController()
      // Google Drive Viewer requires JavaScript for its interactive PDF UI.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Match the dark scaffold so there's no white flash before the page loads.
      ..setBackgroundColor(const Color(0xFF1A1A1A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            dev.log(
              '[PDF] WebView error: ${error.description} '
              '(errorCode=${error.errorCode})',
              name: 'PdfViewer',
            );
            // Only treat as fatal if the main frame fails.
            // Sub-resource errors (ads, analytics in the viewer) are ignorable.
            if (error.isForMainFrame ?? true) {
              if (mounted) setState(() { _isLoading = false; _hasError = true; });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_viewerUrl));
  }

  // ── Retry ─────────────────────────────────────────────────────────────────

  void _retryLoad() {
    setState(() { _isLoading = true; _hasError = false; });
    _webController.loadRequest(Uri.parse(_viewerUrl));
  }

  // ── External open ─────────────────────────────────────────────────────────
  // Opens the *raw* Cloudinary PDF URL in the device browser or PDF app,
  // bypassing the Google Drive wrapper entirely.

  Future<void> _openExternally() async {
    final rawUrl = widget.url.trim();
    if (rawUrl.isEmpty) {
      _toast('No URL available.', success: false);
      return;
    }
    try {
      await launchUrl(
        Uri.parse(rawUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Last-resort: let Android pick any handler (e.g. a PDF app).
      try {
        await launchUrl(
          Uri.parse(rawUrl),
          mode: LaunchMode.platformDefault,
        );
      } catch (e) {
        _toast('Unable to open externally.', success: false);
      }
    }
  }

  // ── Download ──────────────────────────────────────────────────────────────
  // Downloads the PDF directly from the Cloudinary URL (no auth header
  // needed for public raw/upload resources) and saves it to the device's
  // Downloads folder so it appears in the phone's Files app.

  Future<void> _downloadPdf() async {
    final rawUrl = widget.url.trim();
    if (rawUrl.isEmpty) {
      _toast('No download URL.', success: false);
      return;
    }

    setState(() { _isDownloading = true; _downloadProgress = 0; });

    try {
      // ── 1. Android permission check (only needed on API ≤ 28) ────────────
      if (Platform.isAndroid) {
        final sdk = await _androidSdkInt();
        if (sdk < 29) {
          final status = await Permission.storage.request();
          if (status.isDenied) {
            _toast('Storage permission denied.', success: false);
            return;
          }
        }
      }

      // ── 2. Resolve the destination folder ────────────────────────────────
      final saveDir = await _resolveDownloadsDirectory();

      // ── 3. Build a clean, filesystem-safe filename ────────────────────────
      final safeName = widget.title
          .replaceAll(RegExp(r'[^\w\s\-]'), '')   // strip special chars
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');         // spaces → underscores
      final destPath = '${saveDir.path}/$safeName.pdf';

      dev.log('[PDF] Downloading to $destPath', name: 'PdfViewer');

      // ── 4. Download via Dio ───────────────────────────────────────────────
      // No Authorization header needed — Supabase public bucket URLs are
      // accessible without credentials.
      await _dio.download(
        rawUrl,
        destPath,
        options: Options(
          headers: {'Accept': 'application/pdf,*/*'},
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 120),
        ),
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );

      _toast('Saved to Downloads ✓', success: true);
      // Log to backend for trending/analytics — fire-and-forget
      if (widget.materialId != null) {
        ApiClient.logDownload(widget.materialId!);
      }
      // Register in OfflineProvider so it appears in the Offline tab instantly
      if (widget.materialId != null && mounted) {
        final fileSize = await File(destPath).length();
        context.read<OfflineProvider>().addDownload(
          OfflineMaterial(
            materialId: widget.materialId!,
            title: widget.title,
            filePath: destPath,
            fileSizeBytes: fileSize,
            downloadedAt: DateTime.now(),
          ),
        );
      }
    } on DioException catch (e) {
      dev.log('[PDF] Dio error: ${e.type} — ${e.message}', name: 'PdfViewer');
      final reason = e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout
          ? 'Connection timed out. Check your internet.'
          : e.type == DioExceptionType.badResponse
              ? 'Server returned error ${e.response?.statusCode}.'
              : 'Network error. Check your connection.';
      _toast(reason, success: false);
    } on FileSystemException catch (e) {
      dev.log('[PDF] File system error: ${e.message} — ${e.path}', name: 'PdfViewer');
      _toast('Could not save file: ${e.message}', success: false);
    } catch (e) {
      dev.log('[PDF] Download failed: $e', name: 'PdfViewer');
      _toast('Download failed: ${e.toString()}', success: false);
    } finally {
      if (mounted) setState(() { _isDownloading = false; _downloadProgress = 0; });
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<Directory> _resolveDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // Attempt 1: path_provider official Downloads API
      try {
        final dl = await getDownloadsDirectory();
        if (dl != null) {
          if (!await dl.exists()) await dl.create(recursive: true);
          return dl;
        }
      } catch (_) {}

      // Attempt 2 & 3: both spelling variants, created if absent
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

      // Attempt 4: app-scoped external storage
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

  /// Extracts the Android SDK integer from the OS version string.
  /// Falls back to 33 (Android 13) so we never incorrectly request old perms.
  Future<int> _androidSdkInt() async {
    try {
      final version = Platform.operatingSystemVersion;
      final match = RegExp(r'(?:SDK\s*|API\s*)(\d+)').firstMatch(version);
      if (match != null) return int.parse(match.group(1)!);
    } catch (_) {}
    return 33;
  }

  void _toast(String msg, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.error_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
        ]),
        backgroundColor: success ? Colors.green[700] : Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleClose();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // The WebView is always mounted so it keeps its state while
          // loading/error overlays sit on top. This avoids a full reload
          // every time the user taps "Retry".
          if (!_hasError) WebViewWidget(controller: _webController),

          // Loading indicator — shown until the Drive viewer page finishes.
          if (_isLoading && !_hasError) _buildLoadingOverlay(),

          // Error state — shown when the main frame fails to load.
          if (_hasError) _buildErrorView(),

          // Download progress overlay — floats over everything.
          if (_isDownloading) _buildDownloadOverlay(),
        ],
      ),        // closes Stack
    ),          // closes Scaffold
  );            // closes PopScope
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF2C2C2C),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        widget.title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        // Open raw PDF in browser / external PDF app
        IconButton(
          icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
          onPressed: _openExternally,
          tooltip: 'Open in Browser',
        ),
        // Download PDF to device storage
        IconButton(
          icon: const Icon(Icons.download_rounded, color: Colors.white),
          onPressed: _isDownloading ? null : _downloadPdf,
          tooltip: 'Download PDF',
        ),
      ],
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildLoadingOverlay() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Colors.white70,
              strokeWidth: 2.5,
            ),
            SizedBox(height: 16),
            Text(
              'Loading PDF…',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.picture_as_pdf_outlined,
              size: 72,
              color: Colors.white24,
            ),
            const SizedBox(height: 20),
            const Text(
              'Could not load PDF',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'The Google Drive viewer could not render this file.\n'
              'You can retry, open it in your browser, or download it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            // Primary actions row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _retryLoad,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _openExternally,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open Externally'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Secondary: download instead
            TextButton.icon(
              onPressed: _isDownloading ? null : _downloadPdf,
              icon: const Icon(Icons.download_rounded,
                  color: Colors.white60, size: 18),
              label: const Text(
                'Download Instead',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadOverlay() {
    return Container(
      // Semi-transparent scrim over the WebView
      color: Colors.black54,
      child: Center(
        child: Card(
          color: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  // Shows determinate bar once we know the total size,
                  // otherwise stays indeterminate (value == null).
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
                const SizedBox(height: 16),
                Text(
                  _downloadProgress > 0
                      ? 'Downloading ${(_downloadProgress * 100).toInt()}%…'
                      : 'Preparing download…',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    ); // end PopScope
  }
}
