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
// Preprocessing pipeline (applied before segment parsing):
//   • Bare \begin{...}...\end{...} blocks not already inside $$ are
//     automatically wrapped in $$ so they render as display math.
//   • Sanitises common raw-LaTeX leaks (e.g. \begin{aligned} without $$).
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
    final preprocessed = _preprocess(data);
    final segments = _parseSegments(preprocessed);

    // Fast path: pure markdown — zero overhead compared to previous code.
    if (segments.length == 1 && segments.first.type == _SegType.markdown) {
      return MarkdownBody(
        data: preprocessed,
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
        return _SafeMermaidDiagram(source: seg.content, isDark: isDark);
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

// ── Safe Mermaid wrapper with error isolation ─────────────────────────────────

/// Renders a Mermaid diagram with full error isolation.
/// If the diagram fails for any reason, shows a friendly fallback message
/// instead of a parser error or blank space. No Mermaid error should ever
/// reach the user in production.
class _SafeMermaidDiagram extends StatefulWidget {
  final String source;
  final bool isDark;
  const _SafeMermaidDiagram({required this.source, required this.isDark});

  @override
  State<_SafeMermaidDiagram> createState() => _SafeMermaidDiagramState();
}

class _SafeMermaidDiagramState extends State<_SafeMermaidDiagram> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    if (_failed) return _diagramFallback(widget.isDark);

    try {
      return MermaidDiagram(
        source: widget.source,
        isDark: widget.isDark,
        onError: () {
          if (mounted) setState(() => _failed = true);
        },
      );
    } catch (_) {
      return _diagramFallback(widget.isDark);
    }
  }
}

Widget _diagramFallback(bool isDark) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF0F4FF),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isDark
            ? Colors.white.withOpacity(0.09)
            : Colors.black.withOpacity(0.07),
      ),
    ),
    child: Text(
      '📊 This diagram could not be generated. See the explanation above.',
      style: TextStyle(
        fontSize: 13,
        fontStyle: FontStyle.italic,
        color: isDark ? Colors.white54 : Colors.black45,
      ),
    ),
  );
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

// ── Preprocessing ─────────────────────────────────────────────────────────────

/// Sanitise raw AI output before parsing into segments.
///
/// Handles the following leak patterns:
///
/// 1. Bare `\begin{...}...\end{...}` blocks that are NOT already inside
///    a `$$` block are wrapped in `$$` so they render as display math
///    instead of appearing as raw LaTeX source.
///
/// 2. Normalise `\( ... \)` → `$ ... $` and `\[ ... \]` → `$$ ... $$`
///    (some models emit these alternate LaTeX delimiters).
String _preprocess(String text) {
  // Step 1: normalise alternate delimiters
  text = text.replaceAllMapped(
    RegExp(r'\\\((.+?)\\\)', dotAll: true),
    (m) => '\${m.group(1)}\$',
  );
  text = text.replaceAllMapped(
    RegExp(r'\\\[(.+?)\\\]', dotAll: true),
    (m) => '\$\$${m.group(1)}\$\$',
  );

  // Step 2: fix lone backslash row separators inside matrix environments
  // AI generates: \begin{bmatrix} 1 & 2 \ 3 & 4 \end{bmatrix}
  // (where \\ is actually a single backslash in the AI output)
  // Fix by normalising inside bmatrix/pmatrix/vmatrix/matrix.
  text = text.replaceAllMapped(
    RegExp(r'\\begin\{(bmatrix|pmatrix|vmatrix|Bmatrix|matrix)\}([\s\S]*?)\\end\{\1\}'),
    (m) {
      final env = m.group(1)!;
      var body  = m.group(2)!;
      // Replace " \ " that is a lone row separator (not already doubled)
      // Pattern: space backslash space NOT followed by another backslash
      body = body.replaceAllMapped(
        RegExp(r' \\(?![\\a-zA-Z])'),
        (_) => r' \\\\',
      );
      return '\\begin{$env}$body\\end{$env}';
    },
  );

  // Step 3: promote inline $ wrapping an environment to display $$
  text = text.replaceAllMapped(
    RegExp(r'\$([^\$]*?\\begin\{[a-z*]+\}[\s\S]{0,2000}?\\end\{[a-z*]+\}[^\$]*?)\$'),
    (m) => '\$\$\n${m.group(1)!.trim()}\n\$\$',
  );

  // Step 4: promote multiline inline math to display math
  text = text.replaceAllMapped(
    RegExp(r'\$((?:[^\$\\\\]|\\\\.){1,400}?)\$', dotAll: true),
    (m) {
      final inner = m.group(1)!;
      if (inner.contains('\n')) {
        return '\$\$\n${inner.trim()}\n\$\$';
      }
      return m.group(0)!;
    },
  );

  // Step 5: wrap bare \begin{env}...\end{env} not already in $$ with $$
  const _ph = '\x00PH\x00';
  final stash = <String>[];

  String _stashAll(String t, RegExp rx) => t.replaceAllMapped(rx, (m) {
    stash.add(m.group(0)!);
    return '$_ph${stash.length - 1}$_ph';
  });

  text = _stashAll(text, RegExp(r'\$\$[\s\S]*?\$\$'));
  text = _stashAll(text, RegExp(r'\$(?:[^\$\\\\\n]|\\\\.)+?\$'));

  text = text.replaceAllMapped(
    RegExp(r'\\begin\{[a-z*]+\}[\s\S]*?\\end\{[a-z*]+\}'),
    (m) => '\$\$\n${m.group(0)!}\n\$\$',
  );

  for (var i = 0; i < stash.length; i++) {
    text = text.replaceAll('$_ph${i}$_ph', stash[i]);
  }

  return text;
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
///   3. Inline math:            $...$
///
/// Inline math rules to avoid false positives on currency ($5, $USD):
///   - Must contain at least one non-space character after the opening $
///   - Must not be a lone digit or currency amount (e.g. $5, $10.99)
///   - Single-char content is allowed only if it is a letter or Greek-like
///
/// Everything between matches is treated as plain Markdown.
List<_Segment> _parseSegments(String text) {
  final pattern = RegExp(
    r'```mermaid\n([\s\S]*?)```'           // group 1: mermaid source
    r'|\$\$([\s\S]*?)\$\$'                 // group 2: display math
    r'|\$((?:[^$\\\n]|\\.)+?)\$',          // group 3: inline math
    multiLine: true,
  );

  final segments = <_Segment>[];
  int lastEnd = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > lastEnd) {
      segments.add(
          _Segment(_SegType.markdown, text.substring(lastEnd, match.start)));
    }

    if (match.group(1) != null) {
      // Mermaid
      segments.add(_Segment(_SegType.mermaid, match.group(1)!.trim()));
    } else if (match.group(2) != null) {
      // Display math
      segments.add(_Segment(_SegType.displayMath, match.group(2)!.trim()));
    } else if (match.group(3) != null) {
      // Inline math — reject pure-number currency matches like $5 or $10.99
      final inner = match.group(3)!.trim();
      if (RegExp(r'^\d+(\.\d+)?$').hasMatch(inner)) {
        // Looks like a currency amount — treat the whole match as markdown
        segments.add(_Segment(_SegType.markdown, match[0]!));
      } else {
        segments.add(_Segment(_SegType.inlineMath, inner));
      }
    }

    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    segments.add(_Segment(_SegType.markdown, text.substring(lastEnd)));
  }

  if (segments.isEmpty) {
    return [_Segment(_SegType.markdown, text)];
  }

  return segments;
}
