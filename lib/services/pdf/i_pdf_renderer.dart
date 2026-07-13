import 'package:flutter/widgets.dart';

/// Callbacks a renderer implementation reports back to the caller.
///
/// Kept renderer-agnostic on purpose: whichever library sits behind
/// [IPdfRenderer], the app only ever sees "page changed" / "document
/// loaded" / "failed to load" — never library-specific types.
class PdfViewerCallbacks {
  /// Page to jump to once the document finishes loading (1-based).
  /// Used for "Continue from page XX?".
  final int initialPage;

  final ValueChanged<int> onPageChanged;

  /// Fired once, with the total page count, right after the document loads.
  final ValueChanged<int>? onDocumentLoaded;

  final VoidCallback? onLoadFailed;

  const PdfViewerCallbacks({
    this.initialPage = 1,
    required this.onPageChanged,
    this.onDocumentLoaded,
    this.onLoadFailed,
  });
}

/// Contract every offline PDF renderer implementation must satisfy.
///
/// The rest of the app never imports a concrete renderer (e.g. Syncfusion)
/// directly — only [PdfRendererService], which owns the single instance of
/// whichever [IPdfRenderer] is active. Swapping libraries in the future
/// means writing one new class here; no other file changes.
///
/// Deliberately minimal for Phase 1 (offline materials foundation). Capable
/// renderers (like Syncfusion) support far more than this exposes — search,
/// text selection, annotations — but those are wired in as this interface
/// grows in later phases (highlights sync, AI-linked highlights, reading
/// analytics, etc.), not by breaking this contract.
abstract class IPdfRenderer {
  /// Builds a widget that renders [filePath] — a fully local file path —
  /// with zero network, auth, or backend calls of any kind.
  Widget buildViewer({
    required String filePath,
    required PdfViewerCallbacks callbacks,
  });
}
