// lib/screens/pdf/pdf_web_panels_stub.dart
//
// MOBILE / DESKTOP stub.
// Loaded on all non-web builds via the conditional import in
// pdf_viewer_screen.dart:
//
//   import 'pdf_web_panels_stub.dart'
//       if (dart.library.html) 'pdf_web_panels.dart';
//
// Exposes the same API as pdf_web_panels.dart but does nothing —
// mobile uses webview_flutter instead of an iframe.
// This file must NEVER import dart:ui_web or dart:html.

import 'package:flutter/material.dart';

/// No-op on mobile/desktop — mobile uses WebViewWidget instead.
void registerPdfViewFactory(String viewType, String url) {
  // Not used on mobile. WebViewController handles PDF display.
}

/// Placeholder widget — never actually rendered on mobile/desktop.
/// The pdf_viewer_screen conditionally shows WebViewWidget on mobile
/// and PdfWebView on web.
class PdfWebView extends StatelessWidget {
  final String viewType;

  const PdfWebView({super.key, required this.viewType});

  @override
  Widget build(BuildContext context) {
    // This widget is never built on mobile — the screen uses WebViewWidget.
    // Returning a SizedBox ensures no crash if somehow reached.
    return const SizedBox.shrink();
  }
}
