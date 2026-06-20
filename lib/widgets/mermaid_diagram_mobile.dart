// lib/widgets/mermaid_diagram_mobile.dart
//
// MOBILE-ONLY implementation of MermaidDiagram.
// Loaded via conditional import in mermaid_diagram.dart:
//   if (dart.library.io) 'mermaid_diagram_mobile.dart'
//
// Uses webview_flutter (already in pubspec) to render a self-contained
// HTML page with Mermaid.js loaded from CDN.
// The WebView posts its rendered content height back via a JavaScript
// channel so Flutter can size the widget precisely.

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MermaidDiagram extends StatefulWidget {
  final String source;
  final bool isDark;
  final VoidCallback? onError;

  const MermaidDiagram({
    super.key,
    required this.source,
    required this.isDark,
    this.onError,
  });

  @override
  State<MermaidDiagram> createState() => _MermaidDiagramMobileState();
}

class _MermaidDiagramMobileState extends State<MermaidDiagram> {
  late final WebViewController _controller;
  double _height = 280;
  bool _loaded = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final theme = widget.isDark ? 'dark' : 'default';
    // Escape characters that could break the embedded HTML/JS strings.
    final safe = widget.source
        .replaceAll('\\', '\\\\')
        .replaceAll('`', '\\`')
        .replaceAll('\$', '\\\$');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (msg) {
          if (msg.message.startsWith('height:')) {
            final h = double.tryParse(msg.message.substring(7));
            if (h != null && h > 0 && mounted) {
              setState(() => _height = h + 24);
            }
          } else if (msg.message == 'error') {
            if (mounted) {
              setState(() => _error = true);
              widget.onError?.call();
            }
          }
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() { _error = true; _loaded = true; });
        },
      ))
      ..loadHtmlString(_buildHtml(safe, theme));
  }

  String _buildHtml(String safeSource, String theme) {
    final bgColor = widget.isDark ? '#1A1A1A' : '#F8F9FF';
    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body {
    background: $bgColor;
    overflow-x: hidden;
  }
  .wrap {
    padding: 12px;
    display: flex;
    justify-content: center;
    align-items: flex-start;
  }
  .mermaid svg {
    max-width: 100%;
    height: auto !important;
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
<div class="wrap">
  <div class="mermaid" id="diagram">$safeSource</div>
</div>
<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
<script>
  mermaid.initialize({
    startOnLoad: false,
    theme: '$theme',
    securityLevel: 'loose',
    fontFamily: 'system-ui, -apple-system, sans-serif',
  });

  mermaid.run({ nodes: [document.getElementById('diagram')] })
    .then(function() {
      var h = document.body.scrollHeight;
      FlutterBridge.postMessage('height:' + h);
    })
    .catch(function(err) {
      // Never show raw parser errors to users — signal Flutter instead.
      FlutterBridge.postMessage('error');
    });
</script>
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: _height,
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
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (!_loaded && !_error)
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
