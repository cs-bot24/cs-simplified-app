import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'i_pdf_renderer.dart';

/// [IPdfRenderer] implementation backed by `syncfusion_flutter_pdfviewer`.
///
/// This is the ONLY file in the app that should import
/// `package:syncfusion_flutter_pdfviewer`. Everything else — screens,
/// providers, other services — talks to [PdfRendererService] /
/// [IPdfRenderer] only. If Syncfusion is ever swapped out, this is the
/// only file that needs to change.
class SyncfusionPdfRenderer implements IPdfRenderer {
  @override
  Widget buildViewer({
    required String filePath,
    required PdfViewerCallbacks callbacks,
  }) {
    return _SyncfusionViewer(filePath: filePath, callbacks: callbacks);
  }
}

class _SyncfusionViewer extends StatefulWidget {
  final String filePath;
  final PdfViewerCallbacks callbacks;

  const _SyncfusionViewer({required this.filePath, required this.callbacks});

  @override
  State<_SyncfusionViewer> createState() => _SyncfusionViewerState();
}

class _SyncfusionViewerState extends State<_SyncfusionViewer> {
  final PdfViewerController _controller = PdfViewerController();
  bool _jumpedToInitialPage = false;

  @override
  Widget build(BuildContext context) {
    return SfPdfViewer.file(
      // Local file only — Syncfusion never touches the network here.
      File(widget.filePath),
      controller: _controller,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      enableDoubleTapZooming: true,
      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
        widget.callbacks.onDocumentLoaded?.call(details.document.pages.count);
        final target = widget.callbacks.initialPage;
        if (!_jumpedToInitialPage && target > 1 && target <= details.document.pages.count) {
          _jumpedToInitialPage = true;
          // Deferred a frame so the viewer has laid out before jumping.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _controller.jumpToPage(target);
          });
        }
      },
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        widget.callbacks.onLoadFailed?.call();
      },
      onPageChanged: (PdfPageChangedDetails details) {
        widget.callbacks.onPageChanged(details.newPageNumber);
      },
    );
  }
}
