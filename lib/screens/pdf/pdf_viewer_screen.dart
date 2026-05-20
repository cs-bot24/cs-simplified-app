import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/constants.dart';
import '../../widgets/loading_view.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  const PdfViewerScreen({super.key, required this.url, required this.title});
  @override State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _localPath;
  bool    _loading  = true;
  String? _error;
  int     _pages    = 0;
  int     _current  = 0;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    try {
      final res = await http.get(Uri.parse(widget.url));
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/temp_${widget.title.hashCode}.pdf');
      await file.writeAsBytes(res.bodyBytes);
      if (mounted) setState(() { _localPath = file.path; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load PDF.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.primaryColorValue),
        foregroundColor: Colors.white,
        title: Text(widget.title,
            style: const TextStyle(fontSize: 15),
            overflow: TextOverflow.ellipsis),
        elevation: 0,
        actions: [
          if (_pages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('${_current + 1} / $_pages',
                    style: const TextStyle(color: Colors.white70)),
              ),
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.white54, size: 64),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: Colors.white54)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          setState(() { _loading = true; _error = null; });
                          _downloadPdf();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : PDFView(
                  filePath: _localPath!,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: true,
                  pageFling: true,
                  onRender: (pages) =>
                      setState(() => _pages = pages ?? 0),
                  onPageChanged: (page, _) =>
                      setState(() => _current = page ?? 0),
                  onError: (e) =>
                      setState(() => _error = 'Error rendering PDF.'),
                ),
    );
  }
}
