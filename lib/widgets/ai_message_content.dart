// lib/widgets/ai_message_content.dart
//
// Shared AI message renderer used by ALL AI systems in CS Simplified:
//   • AiTutorScreen        (ai_tutor_screen.dart  — _MessageBubble)
//   • WebAiPanel           (pdf_web_panels.dart   — message list)
//   • AiLecturerScreen     (ai_lecturer_screen.dart — _SystemMessage,
//                                                     _LecturerBubble)
//
// Drop-in replacement for MarkdownBody that additionally renders:
//   1. LaTeX math — $...$ (inline) and $$...$$ (display block)
//      via flutter_math_fork (pure-Dart KaTeX port, works on all platforms)
//   2. Mermaid diagrams — ```mermaid ... ``` fenced code blocks
//      via MermaidDiagram (platform-adaptive: web HtmlElementView,
//      mobile webview_flutter)
//   3. Everything else — standard flutter_markdown MarkdownBody
//
// The message text is split into ordered segments before rendering.
// Each segment is one of: markdown text, inline math, display math,
// or a mermaid block. Rendering is done in a Column of widgets.
//
// Usage:
//   AiMessageContent(
//     data:   message.text,   // the raw AI response string
//     isDark: isDark,         // drive colour scheme
//   )
//
// The optional [styleSheet] parameter lets callers override markdown
// styles. When omitted, the built-in style matching the existing app
// theme is used.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'mermaid_diagram.dart';

// ── Public widget ─────────────────────────────────────────────────────────────

class AiMessageContent extends StatelessWidget {
  /// The raw AI response text. May contain Markdown, LaTeX math, and/or
  /// Mermaid fenced code blocks.
  final String data;

  /// Controls text / background colours. Match the surrounding bubble's
  /// brightness.
  final bool isDark;

  /// Optional custom Markdown stylesheet. When null the default style that
  /// matches the existing AI bubble design is used.
  final MarkdownStyleSheet? styleSheet;

  const AiMessageContent({
    super.key,
    required this.data,
    required this.isDark,
    this.styleSheet,
  });

  @override
  Widget build(BuildContext context) {
    final segments = _parseSegments(data);

    // Fast path: pure markdown — zero overhead compared to previous code.
    if (segments.length == 1 && segments.first.type == _SegType.markdown) {
      return MarkdownBody(
        data: data,
        selectable: true,
        styleSheet: styleSheet ?? _defaultStyle(isDark),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final seg in segments) _buildSegment(context, seg),
      ],
    );
  }

  Widget _buildSegment(BuildContext context, _Segment seg) {
    switch (seg.type) {
      // ── Plain Markdown ──────────────────────────────────────────────────
      case _SegType.markdown:
        final trimmed = seg.content.trim();
        if (trimmed.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: MarkdownBody(
            data: trimmed,
            selectable: true,
            styleSheet: styleSheet ?? _defaultStyle(isDark),
          ),
        );

      // ── Inline math: $...$ ──────────────────────────────────────────────
      case _SegType.inlineMath:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Math.tex(
            seg.content,
            textStyle: TextStyle(
              fontSize: 15,
              color: isDark
                  ? Colors.white.withOpacity(0.9)
                  : Colors.black87,
            ),
            onErrorFallback: (FlutterMathException err) => _MathFallback(
              content: seg.content,
              isDark: isDark,
            ),
          ),
        );

      // ── Display math: $$...$$ ────────────────────────────────────────────
      case _SegType.displayMath:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E1E2E)
                : const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.09)
                  : Colors.black.withOpacity(0.07),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              seg.content,
              textStyle: TextStyle(
                fontSize: 17,
                color: isDark
                    ? Colors.white.withOpacity(0.9)
                    : Colors.black87,
              ),
              onErrorFallback: (FlutterMathException err) => _MathFallback(
                content: seg.content,
                isDark: isDark,
              ),
            ),
          ),
        );

      // ── Mermaid diagram: ```mermaid...``` ───────────────────────────────
      case _SegType.mermaid:
        return MermaidDiagram(
          source: seg.content,
          isDark: isDark,
        );
    }
  }

  // ── Default MarkdownStyleSheet matching existing AI bubble design ─────────

  static MarkdownStyleSheet _defaultStyle(bool isDark) {
    final textColor =
        isDark ? Colors.white.withOpacity(0.87) : Colors.black87;
    final dimColor =
        isDark ? Colors.white.withOpacity(0.70) : Colors.black54;

    return MarkdownStyleSheet(
      p: TextStyle(fontSize: 14, color: textColor, height: 1.55),
      h1: TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
      h2: TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
      h3: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
      strong: TextStyle(fontWeight: FontWeight.bold, color: textColor),
      em: TextStyle(fontStyle: FontStyle.italic, color: textColor),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        backgroundColor: isDark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFE8ECF8),
        color:
            isDark ? const Color(0xFF82B1FF) : const Color(0xFF1A237E),
      ),
      codeblockDecoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFE8ECF8),
        borderRadius: BorderRadius.circular(8),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquote:
          TextStyle(fontSize: 14, color: dimColor, fontStyle: FontStyle.italic),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.3)
                : Colors.black26,
            width: 3,
          ),
        ),
      ),
      blockquotePadding:
          const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      listBullet: TextStyle(color: textColor),
      tableHead: TextStyle(fontWeight: FontWeight.bold, color: textColor),
      tableBody: TextStyle(color: textColor),
      tableBorder: TableBorder.all(
        color: isDark
            ? Colors.white.withOpacity(0.15)
            : Colors.black12,
      ),
      tableColumnWidth: const FlexColumnWidth(),
      tableCellsPadding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      h1Padding: const EdgeInsets.only(top: 8, bottom: 4),
      h2Padding: const EdgeInsets.only(top: 6, bottom: 3),
      h3Padding: const EdgeInsets.only(top: 4, bottom: 2),
    );
  }
}

// ── Math error fallback ───────────────────────────────────────────────────────

class _MathFallback extends StatelessWidget {
  final String content;
  final bool isDark;
  const _MathFallback({required this.content, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      content,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: isDark ? Colors.white60 : Colors.black54,
      ),
    );
  }
}

// ── Segment model & parser ────────────────────────────────────────────────────

enum _SegType { markdown, inlineMath, displayMath, mermaid }

class _Segment {
  final _SegType type;
  final String content;
  const _Segment(this.type, this.content);
}

/// Split [text] into ordered segments.
///
/// Priority (checked in this order inside the combined regex):
///   1. Mermaid fenced blocks:  ```mermaid\n...\n```
///   2. Display math:           $$...$$
///   3. Inline math:            $...$  (single-char excluded to avoid $price)
///
/// Everything between matches is treated as plain Markdown.
List<_Segment> _parseSegments(String text) {
  // Combined pattern — order matters.
  // Mermaid block first (block-level), then display math (also block-level),
  // then inline math. Inline math requires at least 2 chars to avoid false
  // positives on currency symbols like $5 or $USD.
  final pattern = RegExp(
    r'```mermaid\n([\s\S]*?)```'  // group 1: mermaid source
    r'|\$\$([\s\S]*?)\$\$'        // group 2: display math
    r'|\$((?:[^$\\\s]|\\.)[^$\\]*?)\$', // group 3: inline math (≥1 non-space char)
    multiLine: true,
  );

  final segments = <_Segment>[];
  int lastEnd = 0;

  for (final match in pattern.allMatches(text)) {
    // Capture any markdown text before this match.
    if (match.start > lastEnd) {
      segments.add(
          _Segment(_SegType.markdown, text.substring(lastEnd, match.start)));
    }

    if (match.group(1) != null) {
      segments.add(_Segment(_SegType.mermaid, match.group(1)!.trim()));
    } else if (match.group(2) != null) {
      segments.add(_Segment(_SegType.displayMath, match.group(2)!.trim()));
    } else if (match.group(3) != null) {
      segments.add(_Segment(_SegType.inlineMath, match.group(3)!.trim()));
    }

    lastEnd = match.end;
  }

  // Capture any trailing markdown text after the last match.
  if (lastEnd < text.length) {
    segments.add(_Segment(_SegType.markdown, text.substring(lastEnd)));
  }

  // If nothing was matched, return the whole text as markdown.
  if (segments.isEmpty) {
    return [_Segment(_SegType.markdown, text)];
  }

  return segments;
}
