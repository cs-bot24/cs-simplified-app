import 'dart:developer' as dev;
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url, title;
  const PdfViewerScreen({super.key, required this.url, required this.title});
  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _pdfCtrl = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfKey = GlobalKey();
  final Dio _dio = Dio();

  bool _loading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _darkMode = true;
  bool _saving = false;
  double _downloadProgress = 0;
  String? _savedPath; // path used for Save to Device

  @override
  void initState() {
    super.initState();
    // Pre-fetch in background for Save to Device — viewer uses network directly
    _prefetchForDownload();
  }

  @override
  void dispose() {
    _pdfCtrl.dispose();
    _dio.close();
    super.dispose();
  }

  // Pre-download to temp so Save to Device is instant after viewing
  Future<void> _prefetchForDownload() async {
    final rawUrl = widget.url.trim();
    if (rawUrl.isEmpty) return;
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/pdf_save_${rawUrl.hashCode.abs()}.pdf';
      final file = File(path);
      if (await file.exists() && await file.length() > 1024) {
        _savedPath = path;
        return;
      }
      await _dio.download(
        rawUrl, path,
        options: Options(
          headers: {'Accept': 'application/pdf,*/*'},
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 60),
        ),
        onReceiveProgress: (r, t) {
          if (t > 0 && mounted) setState(() => _downloadProgress = r / t);
        },
      );
      if (await File(path).length() > 100) _savedPath = path;
    } catch (e) {
      dev.log('[PDF] Prefetch failed (save may not work): $e', name: 'PdfViewer');
    }
  }

  // ── Save to Device ────────────────────────────────────────────────────────
  Future<void> _saveToDevice() async {
    if (_savedPath == null) {
      _toast('Still downloading, please wait…', success: false);
      return;
    }
    setState(() => _saving = true);
    try {
      final safeName = widget.title
          .replaceAll(RegExp(r'[^\w\s\-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');

      if (Platform.isAndroid) {
        final sdk = await _androidSdkInt();
        if (sdk < 29) {
          final status = await Permission.storage.request();
          if (status.isDenied) {
            _toast('Storage permission denied.', success: false);
            return;
          }
        }
        Directory saveDir = Directory('/storage/emulated/0/Download');
        if (!await saveDir.exists()) {
          final ext = await getExternalStorageDirectory();
          saveDir = ext ?? await getApplicationDocumentsDirectory();
        }
        if (!await saveDir.exists()) await saveDir.create(recursive: true);
        final dest = '${saveDir.path}/$safeName.pdf';
        await File(_savedPath!).copy(dest);
        _toast('Saved to Downloads ✓', success: true);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final dest = '${dir.path}/$safeName.pdf';
        await File(_savedPath!).copy(dest);
        _toast('Saved to Files ✓', success: true);
      }
    } catch (e) {
      _toast('Could not save: $e', success: false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<int> _androidSdkInt() async {
    try {
      final v = Platform.operatingSystemVersion;
      final match = RegExp(r'(?:SDK\s*|API\s*)(\d+)').firstMatch(v);
      if (match != null) return int.parse(match.group(1)!);
    } catch (_) {}
    return 33;
  }

  // ── Open in external browser ──────────────────────────────────────────────
  Future<void> _openExternally() async {
    final raw = widget.url.trim();
    if (raw.isEmpty) { _toast('No URL available.', success: false); return; }
    try {
      final uri = Uri.parse(raw);
      // Skip canLaunchUrl check — it can falsely return false on some devices.
      // launchUrl with externalApplication directly opens Chrome/browser.
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Last resort: try platformDefault which lets Android pick any handler
      try {
        await launchUrl(Uri.parse(raw), mode: LaunchMode.platformDefault);
      } catch (_) {
        _toast('Unable to open browser.', success: false);
      }
    }
  }

  void _jumpToPage() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Jump to Page'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '1 – $_totalPages',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final p = int.tryParse(ctrl.text);
              if (p != null && p >= 1 && p <= _totalPages) _pdfCtrl.jumpToPage(p);
              Navigator.pop(context);
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  void _toast(String msg, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(success ? Icons.check_circle : Icons.error_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: success ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bg    = _darkMode ? const Color(0xFF1A1A1A) : Colors.grey[100]!;
    final barBg = _darkMode ? const Color(0xFF2C2C2C) : Colors.white;
    final txtClr = _darkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: barBg,
        elevation: 0,
        iconTheme: IconThemeData(color: txtClr),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: txtClr),
                overflow: TextOverflow.ellipsis),
            if (_totalPages > 0)
              Text('Page $_currentPage of $_totalPages',
                  style: TextStyle(fontSize: 11,
                      color: _darkMode ? Colors.white54 : Colors.grey[500])),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: txtClr),
            onPressed: () => setState(() => _darkMode = !_darkMode),
            tooltip: 'Toggle theme',
          ),
          if (_totalPages > 0)
            IconButton(
              icon: Icon(Icons.menu_book_outlined, color: txtClr),
              onPressed: _jumpToPage,
              tooltip: 'Jump to page',
            ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: txtClr),
            onSelected: (v) {
              if (v == 'save')    _saveToDevice();
              if (v == 'browser') _openExternally();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'save',
                  child: Row(children: [
                    Icon(Icons.download_rounded, size: 18), SizedBox(width: 10),
                    Text('Save to Device'),
                  ])),
              const PopupMenuItem(value: 'browser',
                  child: Row(children: [
                    Icon(Icons.open_in_new, size: 18), SizedBox(width: 10),
                    Text('Open in Browser'),
                  ])),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildViewer(bg),
          if (_saving)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Saving…'),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildViewer(Color bg) {
    final rawUrl = widget.url.trim();

    if (rawUrl.isEmpty) {
      return _errorView(bg, 'No PDF URL provided.');
    }

    if (_error != null) {
      return _errorView(bg, _error!);
    }

    return Stack(
      children: [
        // PRIMARY FIX: Use SfPdfViewer.network() directly.
        // No Dio download needed for viewing — Syncfusion fetches it internally.
        // This eliminates all temp-file caching issues and works for any
        // public Cloudinary raw/upload URL out of the box.
        SfPdfViewer.network(
          rawUrl,
          key: _pdfKey,
          controller: _pdfCtrl,
          headers: const {'Accept': 'application/pdf,*/*'},
          pageLayoutMode: PdfPageLayoutMode.continuous,
          scrollDirection: PdfScrollDirection.vertical,
          enableDoubleTapZooming: true,
          pageSpacing: 4,
          onDocumentLoadFailed: (d) {
            dev.log('[PDF] Load failed: ${d.description}', name: 'PdfViewer');
            if (mounted) setState(() => _error = d.description);
          },
          onDocumentLoaded: (d) {
            dev.log('[PDF] Loaded — ${d.document.pages.count} pages', name: 'PdfViewer');
            if (mounted) setState(() {
              _totalPages = d.document.pages.count;
              _loading = false;
            });
          },
          onPageChanged: (d) {
            if (mounted) setState(() => _currentPage = d.newPageNumber);
          },
        ),

        // Loading overlay — shown until onDocumentLoaded fires
        if (_loading)
          Container(
            color: bg,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('Loading PDF…',
                    style: TextStyle(
                        color: _darkMode ? Colors.white54 : Colors.grey[600],
                        fontSize: 13)),
                if (_downloadProgress > 0 && _downloadProgress < 1) ...[
                  const SizedBox(height: 8),
                  Text('Caching ${(_downloadProgress * 100).toInt()}%…',
                      style: TextStyle(
                          color: _darkMode ? Colors.white38 : Colors.grey[400],
                          fontSize: 11)),
                ],
              ]),
            ),
          ),

        // Zoom controls
        Positioned(
          bottom: 24, right: 16,
          child: Column(children: [
            _ZoomBtn(Icons.add,    () => _pdfCtrl.zoomLevel = (_pdfCtrl.zoomLevel + 0.25).clamp(0.5, 4.0)),
            const SizedBox(height: 8),
            _ZoomBtn(Icons.remove, () => _pdfCtrl.zoomLevel = (_pdfCtrl.zoomLevel - 0.25).clamp(0.5, 4.0)),
          ]),
        ),
      ],
    );
  }

  Widget _errorView(Color bg, String message) {
    return Container(
      color: bg,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.picture_as_pdf_outlined, size: 72,
              color: _darkMode ? Colors.white30 : Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Could not load PDF',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: _darkMode ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _darkMode ? Colors.white54 : Colors.grey[600],
                  fontSize: 13)),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton.icon(
              onPressed: () => setState(() { _error = null; _loading = true; }),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _darkMode ? Colors.white : null,
                side: BorderSide(color: _darkMode ? Colors.white30 : Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _openExternally,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open in Browser'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
