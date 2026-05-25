import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url, title;
  const PdfViewerScreen({super.key, required this.url, required this.title});
  @override State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _path;
  bool    _loading = true;
  String? _error;
  int _pages = 0, _current = 0;

  @override
  void initState() { super.initState(); _download(); }

  Future<void> _download() async {
    try {
      final res  = await http.get(Uri.parse(widget.url));
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/pdf_${widget.title.hashCode}.pdf');
      await file.writeAsBytes(res.bodyBytes);
      if (mounted) setState(() { _path = file.path; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load PDF.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis),
        actions: [
          if (_pages > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text('${_current + 1} / $_pages',
                  style: const TextStyle(color: Colors.white70))),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, color: Colors.white54, size: 64),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.white54)),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: () {
                    setState(() { _loading = true; _error = null; });
                    _download();
                  }, child: const Text('Retry')),
                ]))
              : PDFView(
                  filePath: _path!,
                  enableSwipe: true, swipeHorizontal: false,
                  autoSpacing: true, pageFling: true,
                  onRender: (p) => setState(() => _pages = p ?? 0),
                  onPageChanged: (p, _) => setState(() => _current = p ?? 0),
                  onError: (_) => setState(() => _error = 'Render error.'),
                ),
    );
  }
}
