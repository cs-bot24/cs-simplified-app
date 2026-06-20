// lib/widgets/mermaid_diagram_stub.dart
//
// Stub implementation of MermaidDiagram used when neither dart:html
// nor dart:io is available (e.g. tests, unsupported platforms).
// Simply renders the raw Mermaid source as monospace text.

import 'package:flutter/material.dart';

class MermaidDiagram extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.08),
        ),
      ),
      child: SelectableText(
        source,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }
}
