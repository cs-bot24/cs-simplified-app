// lib/screens/pdf/pdf_web_panels.dart
//
// WEB-ONLY implementation.
// Loaded via conditional import:
//   import 'pdf_web_panels_stub.dart'
//       if (dart.library.html) 'pdf_web_panels.dart';
//
// Registers an <iframe> view factory so Flutter web can embed a PDF URL
// directly in the page using HtmlElementView.
// This file MUST NOT be imported directly — only through the conditional
// import above, because dart:ui_web is not available on mobile/desktop.

// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';

/// Registers a view factory for [viewType] that renders [url] in an <iframe>.
/// Call once before building a [PdfWebView] with the same [viewType].
///
/// Typically called inside initState():
///   registerPdfViewFactory('pdf-viewer-${material.id}', material.pdfUrl);
void registerPdfViewFactory(String viewType, String url) {
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = html.IFrameElement()
      ..src = url
      ..style.border  = 'none'
      ..style.width   = '100%'
      ..style.height  = '100%'
      ..allowFullscreen = true;

    // Allow necessary iframe permissions for Google Drive / PDF viewers
    iframe.setAttribute('allow', 'fullscreen');

    return iframe;
  });
}

/// A Flutter widget that displays a previously-registered PDF iframe view.
///
/// Usage:
///   PdfWebView(viewType: 'pdf-viewer-${material.id}')
class PdfWebView extends StatelessWidget {
  final String viewType;

  const PdfWebView({super.key, required this.viewType});

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: viewType);
  }
}
