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
  @override State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _pdfCtrl = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfKey = GlobalKey();
  final Dio _dio = Dio();

  bool _loading  = true;
  String? _error;
  String? _localPath;
  int _currentPage = 1;
  int _totalPages  = 0;
  double _progress = 0;
  bool _darkMode   = true;
  bool _saving     = false;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _pdfCtrl.dispose();
    _dio.close();
    super.dispose();
  }

  // ── Load (download to temp) ───────────────────────────────────────────────

  Future<void> _loadPdf() async {
    setState(() { _loading = true; _error = null; _progress = 0; });

    final rawUrl = widget.url.trim();
    dev.log('[PDF] Loading: $rawUrl', name: 'PdfViewer');

    if (rawUrl.isEmpty) {
      setState(() { _error = 'PDF URL is empty.'; _loading = false; });
      return;
    }

    try {
      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/pdf_${rawUrl.hashCode}.pdf';
      final file = File(path);

      // Use cached file if already downloaded this session
      if (await file.exists() && await file.length() > 1024) {
        dev.log('[PDF] Using cached file: $path', name: 'PdfViewer');
        setState(() { _localPath = path; _loading = false; });
        return;
      }

      dev.log('[PDF] Downloading…', name: 'PdfViewer');
      await _dio.download(
        rawUrl,
        path,
        options: Options(
          headers: {'Accept': 'application/pdf,*/*'},
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 30),
        ),
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );

      final downloaded = File(path);
      if (!await downloaded.exists() || await downloaded.length() < 100) {
        throw Exception('Downloaded file is empty or corrupted.');
      }

      dev.log('[PDF] Downloaded OK: $path', name: 'PdfViewer');
      if (mounted) setState(() { _localPath = path; _loading = false; });

    } on DioException catch (e) {
      dev.log('[PDF] DioException: ${e.type} ${e.message}', name: 'PdfViewer');
      String msg;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
          msg = 'Connection timed out. Please check your internet.';
          break;
        case DioExceptionType.connectionError:
          msg = 'Unable to connect. Check your internet connection.';
          break;
        case DioExceptionType.badResponse:
          msg = 'Server error (${e.response?.statusCode}). '
              'The file may not be accessible.';
          break;
        default:
          msg = 'Failed to load PDF: ${e.message}';
      }
      if (mounted) setState(() { _error = msg; _loading = false; });
    } catch (e) {
      dev.log('[PDF] Error: $e', name: 'PdfViewer');
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Save to Downloads ─────────────────────────────────────────────────────

  Future<void> _saveToDevice() async {
    if (_localPath == null) return;
    setState(() => _saving = true);

    try {
      // Request storage permission on Android < 13
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (status.isDenied) {
          _toast('Storage permission denied.', success: false);
          setState(() => _saving = false);
          return;
        }
      }

      final downloadsDir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();

      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final safeName = widget.title
          .replaceAll(RegExp(r'[^\w\s\-]'), '')
          .trim()
          .replaceAll(' ', '_');
      final dest = '${downloadsDir.path}/$safeName.pdf';
      await File(_localPath!).copy(dest);
      dev.log('[PDF] Saved to: $dest', name: 'PdfViewer');
      _toast('Saved to Downloads ✓', success: true);
    } catch (e) {
      dev.log('[PDF] Save error: $e', name: 'PdfViewer');
      _toast('Could not save file: $e', success: false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Open in browser ───────────────────────────────────────────────────────

  Future<void> _openExternally() async {
    final uri = Uri.parse(widget.url.trim());
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _toast('Unable to open browser.', success: false);
      }
    } catch (e) {
      _toast('Unable to open link.', success: false);
    }
  }

  // ── Jump to page dialog ───────────────────────────────────────────────────

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
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final p = int.tryParse(ctrl.text);
              if (p != null && p >= 1 && p <= _totalPages) {
                _pdfCtrl.jumpToPage(p);
              }
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bg     = _darkMode ? const Color(0xFF1A1A1A) : Colors.grey[100]!;
    final barBg  = _darkMode ? const Color(0xFF2C2C2C) : Colors.white;
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
                style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w600, color: txtClr),
                overflow: TextOverflow.ellipsis),
            if (_totalPages > 0)
              Text('Page $_currentPage of $_totalPages',
                  style: TextStyle(fontSize: 11,
                      color: _darkMode ? Colors.white54 : Colors.grey[500])),
          ],
        ),
        actions: [
          // Dark/light toggle
          IconButton(
            icon: Icon(
              _darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: txtClr,
            ),
            onPressed: () => setState(() => _darkMode = !_darkMode),
            tooltip: 'Toggle theme',
          ),
          // Jump to page
          if (_totalPages > 0)
            IconButton(
              icon: Icon(Icons.menu_book_outlined, color: txtClr),
              onPressed: _jumpToPage,
              tooltip: 'Jump to page',
            ),
          // More options
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: txtClr),
            onSelected: (v) {
              if (v == 'save')     _saveToDevice();
              if (v == 'browser')  _openExternally();
              if (v == 'reload')   _loadPdf();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'save',
                  child: Row(children: [
                    Icon(Icons.download_rounded, size: 18),
                    SizedBox(width: 10), Text('Save to Device'),
                  ])),
              const PopupMenuItem(value: 'browser',
                  child: Row(children: [
                    Icon(Icons.open_in_new, size: 18),
                    SizedBox(width: 10), Text('Open in Browser'),
                  ])),
              const PopupMenuItem(value: 'reload',
                  child: Row(children: [
                    Icon(Icons.refresh_rounded, size: 18),
                    SizedBox(width: 10), Text('Reload'),
                  ])),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(bg),
          // Save progress overlay
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

  Widget _buildBody(Color bg) {
    // ── Loading state ──────────────────────────────────────────────────────
    if (_loading) {
      return Container(
        color: bg,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 220,
              child: Column(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 5,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _progress > 0
                      ? 'Loading ${(_progress * 100).toInt()}%…'
                      : 'Preparing PDF…',
                  style: TextStyle(
                      color: _darkMode ? Colors.white54 : Colors.grey[600],
                      fontSize: 13),
                ),
              ]),
            ),
          ]),
        ),
      );
    }

    // ── Error state ────────────────────────────────────────────────────────
    if (_error != null) {
      return Container(
        color: bg,
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.picture_as_pdf_outlined,
                size: 72,
                color: _darkMode ? Colors.white30 : Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Could not load PDF',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                    color: _darkMode ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _darkMode ? Colors.white54 : Colors.grey[600],
                    fontSize: 13)),
            const SizedBox(height: 8),
            // Show URL for debugging
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                widget.url,
                style: TextStyle(
                    fontSize: 10,
                    color: _darkMode ? Colors.white38 : Colors.grey[500],
                    fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              OutlinedButton.icon(
                onPressed: _loadPdf,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _darkMode ? Colors.white : null,
                  side: BorderSide(
                      color: _darkMode ? Colors.white30 : Colors.grey),
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

    // ── PDF viewer ─────────────────────────────────────────────────────────
    return Stack(
      children: [
        SfPdfViewer.file(
          File(_localPath!),
          key: _pdfKey,
          controller: _pdfCtrl,
          pageLayoutMode: PdfPageLayoutMode.continuous,
          scrollDirection: PdfScrollDirection.vertical,
          enableDoubleTapZooming: true,
          pageSpacing: 4,
          onPageChanged: (d) => setState(() => _currentPage = d.newPageNumber),
          onDocumentLoaded: (d) =>
              setState(() => _totalPages = d.document.pages.count),
          onDocumentLoadFailed: (d) => setState(() {
            _error = 'Render failed: ${d.description}';
            _localPath = null;
          }),
        ),
        // Zoom buttons
        Positioned(
          bottom: 24, right: 16,
          child: Column(
            children: [
              _ZoomBtn(Icons.add, () {
                _pdfCtrl.zoomLevel =
                    (_pdfCtrl.zoomLevel + 0.25).clamp(0.5, 4.0);
              }),
              const SizedBox(height: 8),
              _ZoomBtn(Icons.remove, () {
                _pdfCtrl.zoomLevel =
                    (_pdfCtrl.zoomLevel - 0.25).clamp(0.5, 4.0);
              }),
            ],
          ),
        ),
      ],
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
        decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
