import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url, title;
  const PdfViewerScreen({super.key, required this.url, required this.title});
  @override State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  bool _loading = true;
  bool _downloading = false;
  String? _error;
  String? _localPath;
  int _currentPage = 1;
  int _totalPages = 0;
  double _loadProgress = 0;
  bool _darkMode = true;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  Future<void> _downloadPdf() async {
    setState(() { _loading = true; _error = null; _loadProgress = 0; });
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];
      int received = 0;

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (contentLength > 0 && mounted) {
          setState(() => _loadProgress = received / contentLength);
        }
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pdf_${widget.url.hashCode}.pdf');
      await file.writeAsBytes(bytes);

      if (mounted) {
        setState(() {
          _localPath = file.path;
          _loading = false;
          _loadProgress = 1.0;
        });
      }
      client.close();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load PDF. Please check your connection.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _savePdf() async {
    if (_localPath == null) return;
    setState(() => _downloading = true);
    try {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final dest = '${downloadsDir.path}/${widget.title.replaceAll(RegExp(r'[^\w\s]'), '')}.pdf';
      await File(_localPath!).copy(dest);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Saved to Downloads'),
            ]),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _openExternally() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showJumpToPageDialog() {
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
              if (p != null && p >= 1 && p <= _totalPages) {
                _pdfController.jumpToPage(p);
              }
              Navigator.pop(context);
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _darkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final appBarColor = _darkMode ? const Color(0xFF2D2D2D) : Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: _darkMode ? Colors.white : null),
                overflow: TextOverflow.ellipsis),
            if (_totalPages > 0)
              Text('Page $_currentPage of $_totalPages',
                  style: TextStyle(
                      fontSize: 11,
                      color: _darkMode ? Colors.white54 : Colors.grey[500])),
          ],
        ),
        actions: [
          // Dark/Light toggle
          IconButton(
            icon: Icon(_darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: _darkMode ? Colors.white70 : null),
            onPressed: () => setState(() => _darkMode = !_darkMode),
            tooltip: 'Toggle Reading Mode',
          ),
          // Jump to page
          if (_totalPages > 0)
            IconButton(
              icon: Icon(Icons.menu_book_outlined,
                  color: _darkMode ? Colors.white70 : null),
              onPressed: _showJumpToPageDialog,
              tooltip: 'Jump to Page',
            ),
          // More options
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert,
                color: _darkMode ? Colors.white70 : null),
            onSelected: (v) {
              if (v == 'download') _savePdf();
              if (v == 'external') _openExternally();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'download',
                  child: Row(children: [
                    Icon(Icons.download_outlined, size: 18),
                    SizedBox(width: 10), Text('Save to Device'),
                  ])),
              const PopupMenuItem(value: 'external',
                  child: Row(children: [
                    Icon(Icons.open_in_new, size: 18),
                    SizedBox(width: 10), Text('Open in Browser'),
                  ])),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Container(
        color: _darkMode ? const Color(0xFF1E1E1E) : Colors.white,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 200,
              child: Column(children: [
                LinearProgressIndicator(
                  value: _loadProgress > 0 ? _loadProgress : null,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  color: Theme.of(context).colorScheme.primary,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 16),
                Text(
                  _loadProgress > 0
                      ? 'Loading ${(_loadProgress * 100).toInt()}%...'
                      : 'Preparing PDF...',
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

    if (_error != null) {
      return Container(
        color: _darkMode ? const Color(0xFF1E1E1E) : Colors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.picture_as_pdf_outlined,
                  color: _darkMode ? Colors.white30 : Colors.grey[400],
                  size: 72),
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
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                OutlinedButton.icon(
                  onPressed: _downloadPdf,
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
        ),
      );
    }

    return Stack(
      children: [
        SfPdfViewer.file(
          File(_localPath!),
          key: _pdfViewerKey,
          controller: _pdfController,
          pageLayoutMode: PdfPageLayoutMode.continuous,
          scrollDirection: PdfScrollDirection.vertical,
          enableDoubleTapZooming: true,
          pageSpacing: 4,
          onPageChanged: (details) {
            setState(() => _currentPage = details.newPageNumber);
          },
          onDocumentLoaded: (details) {
            setState(() => _totalPages = details.document.pages.count);
          },
          onDocumentLoadFailed: (details) {
            setState(() {
              _error = 'Render error: ${details.description}';
              _localPath = null;
            });
          },
        ),
        // Zoom controls (bottom right)
        Positioned(
          bottom: 20,
          right: 16,
          child: Column(
            children: [
              _ZoomButton(
                icon: Icons.add,
                onTap: () => _pdfController.zoomLevel =
                    (_pdfController.zoomLevel + 0.25).clamp(0.5, 4.0),
              ),
              const SizedBox(height: 8),
              _ZoomButton(
                icon: Icons.remove,
                onTap: () => _pdfController.zoomLevel =
                    (_pdfController.zoomLevel - 0.25).clamp(0.5, 4.0),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
