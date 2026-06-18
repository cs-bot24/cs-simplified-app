// lib/widgets/mermaid_diagram_web.dart
//
// WEB-ONLY implementation of MermaidDiagram.
// Loaded via conditional import in mermaid_diagram.dart:
//   if (dart.library.html) 'mermaid_diagram_web.dart'
//
// This file MUST NOT be imported directly — only through the conditional
// import, because dart:ui_web and dart:html are not available on mobile.
//
// Renders a Mermaid diagram using an inline iframe (srcdoc).
// The Mermaid.js library is loaded from jsDelivr CDN inside the iframe so
// it runs in a sandboxed context and does not affect the Flutter app.

// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';

class MermaidDiagram extends StatefulWidget {
  final String source;
  final bool isDark;

  const MermaidDiagram({
    super.key,
    required this.source,
    required this.isDark,
  });

  @override
  State<MermaidDiagram> createState() => _MermaidDiagramWebState();
}

class _MermaidDiagramWebState extends State<MermaidDiagram> {
  late final String _viewType;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    // Use a stable key based on content hash + theme so the same diagram
    // is not re-registered on hot-reload or theme changes.
    _viewType =
        'mermaid-${widget.source.hashCode}-${widget.isDark ? 'd' : 'l'}';
    _registerFactory();
  }

  void _registerFactory() {
    if (_registered) return;
    _registered = true;

    final theme = widget.isDark ? 'dark' : 'default';
    // Escape backticks in the source to avoid breaking the template literal
    // inside the srcdoc HTML.
    final escapedSource = widget.source
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..srcdoc = _buildHtml(escapedSource, theme)
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = false;
      // Allow scripts inside srcdoc iframe.
      iframe.setAttribute('sandbox',
          'allow-scripts allow-same-origin');
      return iframe;
    });
  }

  String _buildHtml(String escapedSource, String theme) {
    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  html, body {
    margin: 0;
    padding: 0;
    background: transparent;
    overflow: hidden;
  }
  .mermaid-wrap {
    padding: 12px;
    display: flex;
    justify-content: center;
    align-items: flex-start;
  }
  .mermaid svg {
    max-width: 100%;
    height: auto;
  }
  .error-text {
    font-family: monospace;
    font-size: 12px;
    color: #cc4444;
    padding: 8px;
    white-space: pre-wrap;
  }
</style>
</head>
<body>
<div class="mermaid-wrap">
  <div class="mermaid">$escapedSource</div>
</div>
<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
  mermaid.initialize({
    startOnLoad: true,
    theme: '$theme',
    securityLevel: 'loose',
    fontFamily: 'system-ui, -apple-system, sans-serif',
  });
  mermaid.run().catch(err => {
    document.querySelector('.mermaid-wrap').innerHTML =
      '<div class="error-text">Diagram error: ' + err.message + '</div>';
  });
</script>
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 320,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }
}
