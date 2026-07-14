import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import 'i_pdf_renderer.dart';

/// [IPdfRenderer] implementation backed by `pdfx`.
///
/// This is the ONLY file in the app that should import `package:pdfx`.
/// Everything else — screens, providers, other services — talks to
/// [PdfRendererService] / [IPdfRenderer] only. If the renderer is ever
/// swapped again, this is the only file that needs to change.
///
/// (Previously used `syncfusion_flutter_pdfviewer`, replaced after its
/// Android plugin failed to compile — legacy v1-embedding code referencing
/// a `PluginRegistry.Registrar` class Flutter has since removed. pdfx is a
/// leaner, MIT-licensed package with no such legacy baggage.)
class PdfxRenderer implements IPdfRenderer {
  @override
  Widget buildViewer({
    required String filePath,
    required PdfViewerCallbacks callbacks,
  }) {
    return _PdfxViewer(filePath: filePath, callbacks: callbacks);
  }
}

class _PdfxViewer extends StatefulWidget {
  final String filePath;
  final PdfViewerCallbacks callbacks;

  const _PdfxViewer({required this.filePath, required this.callbacks});

  @override
  State<_PdfxViewer> createState() => _PdfxViewerState();
}

class _PdfxViewerState extends State<_PdfxViewer> {
  late final PdfController _controller;

  @override
  void initState() {
    super.initState();
    final target = widget.callbacks.initialPage < 1 ? 1 : widget.callbacks.initialPage;
    _controller = PdfController(
      // Local file only — pdfx never touches the network here.
      document: PdfDocument.openFile(widget.filePath),
      initialPage: target,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PdfView(
      controller: _controller,
      onDocumentLoaded: (document) {
        widget.callbacks.onDocumentLoaded?.call(document.pagesCount);
      },
      onPageChanged: (page) {
        widget.callbacks.onPageChanged(page);
      },
      onDocumentError: (error) {
        widget.callbacks.onLoadFailed?.call();
      },
    );
  }
}
