import 'package:flutter/widgets.dart';

import 'i_pdf_renderer.dart';
import 'pdfx_renderer.dart';

/// The only class the rest of the app should call to render a local PDF.
///
/// Usage everywhere else in the app:
/// ```dart
/// PdfRendererService.instance.open(
///   filePath: localPath,
///   callbacks: PdfViewerCallbacks(
///     initialPage: material.lastOpenedPage,
///     onPageChanged: (page) => offlineProvider.recordProgress(materialId, page),
///   ),
/// )
/// ```
///
/// No screen, provider, or widget outside `lib/services/pdf/` should ever
/// import `pdfx` (or any future replacement) directly — that keeps a
/// library swap to a single new [IPdfRenderer] implementation plus a
/// one-line change below.
class PdfRendererService {
  PdfRendererService._();
  static final PdfRendererService instance = PdfRendererService._();

  final IPdfRenderer _renderer = PdfxRenderer();

  /// Renders [filePath] fully offline. Never performs network, auth, or
  /// backend calls — the caller is responsible for having already resolved
  /// a verified local path (see `OfflineMaterialService.resolveLocalPath`).
  Widget open({
    required String filePath,
    required PdfViewerCallbacks callbacks,
  }) {
    return _renderer.buildViewer(filePath: filePath, callbacks: callbacks);
  }
}
