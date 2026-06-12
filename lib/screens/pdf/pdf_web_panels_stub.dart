// lib/screens/pdf/pdf_web_panels_stub.dart
//
// MOBILE / DESKTOP stub.
// Loaded on all non-web builds via the conditional import in
// pdf_viewer_screen.dart:
//
//   import 'pdf_web_panels_stub.dart'
//       if (dart.library.html) 'pdf_web_panels.dart';
//
// Exposes the same public API as pdf_web_panels.dart but does nothing —
// mobile uses webview_flutter instead of an iframe, and _buildWebLayout()
// is only called when kIsWeb is true so these stubs are never rendered.
// This file must NEVER import dart:ui_web or dart:html.

import 'package:flutter/material.dart';

/// No-op on mobile/desktop — mobile uses WebViewController instead.
void registerPdfViewFactory(String viewType, String url) {
  // Not used on mobile. WebViewController handles PDF display.
}

/// Placeholder — never actually rendered on mobile/desktop.
/// pdf_viewer_screen.dart guards _buildWebLayout() behind kIsWeb.
class PdfWebView extends StatelessWidget {
  final String viewType;
  const PdfWebView({super.key, required this.viewType});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Stub for the PDF iframe panel — never rendered on mobile/desktop.
/// The real implementation is in pdf_web_panels.dart (web only).
class WebPdfPanel extends StatelessWidget {
  final String url;
  final String title;
  const WebPdfPanel({super.key, required this.url, required this.title});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Stub for the AI side-panel — never rendered on mobile/desktop.
/// The real implementation is in pdf_web_panels.dart (web only).
class WebAiPanel extends StatelessWidget {
  final int?    materialId;
  final String  materialTitle;
  final String? courseCode;
  final String? levelName;
  final String? categoryName;
  final VoidCallback onClose;

  const WebAiPanel({
    super.key,
    required this.materialId,
    required this.materialTitle,
    required this.courseCode,
    required this.levelName,
    required this.categoryName,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
