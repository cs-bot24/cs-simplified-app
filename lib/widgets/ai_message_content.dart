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

/// Best-effort LaTeX → plain readable text, used ONLY when KaTeX itself
/// couldn't render an expression (Phase 2, Part 5: "Expressions that fail
/// rendering should gracefully fall back to readable mathematical text
/// instead of displaying 'Expression could not be displayed.'"). Not a full
/// LaTeX interpreter — just enough of the common vocabulary (fractions,
/// roots, common symbols, super/subscripts) to give the student something
/// they can actually read instead of a dead-end error notice or, worse, the
/// raw broken markup.
const Map<String, String> _latexSymbolWords = {
  r'\times': '×', r'\div': '÷', r'\pm': '±', r'\mp': '∓',
  r'\leq': '≤', r'\geq': '≥', r'\neq': '≠', r'\approx': '≈', r'\equiv': '≡',
  r'\infty': '∞', r'\partial': '∂', r'\nabla': '∇',
  r'\rightarrow': '→', r'\to': '→', r'\leftarrow': '←', r'\Rightarrow': '⇒',
  r'\cdot': '·', r'\cdots': '⋯', r'\ldots': '…',
  r'\alpha': 'α', r'\beta': 'β', r'\gamma': 'γ', r'\delta': 'δ',
  r'\epsilon': 'ε', r'\theta': 'θ', r'\lambda': 'λ', r'\mu': 'μ',
  r'\pi': 'π', r'\rho': 'ρ', r'\sigma': 'σ', r'\tau': 'τ', r'\phi': 'φ',
  r'\omega': 'ω', r'\Delta': 'Δ', r'\Sigma': 'Σ', r'\Omega': 'Ω',
  r'\in': '∈', r'\notin': '∉', r'\subset': '⊂', r'\cup': '∪', r'\cap': '∩',
  r'\forall': '∀', r'\exists': '∃',
  r'\left': '', r'\right': '', r'\,': ' ', r'\;': ' ', r'\!': '',
};

const Map<String, String> _superscriptDigits = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
  '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
  '+': '⁺', '-': '⁻', 'n': 'ⁿ', 'i': 'ⁱ',
};

String _readableMathFallbackText(String latex) {
  var t = latex;

  // \frac{a}{b} -> (a)/(b) — do this before symbol replacement since it
  // needs the braces intact.
  final fracRe = RegExp(r'\\d?frac\{([^{}]*)\}\{([^{}]*)\}');
  while (fracRe.hasMatch(t)) {
    t = t.replaceAllMapped(fracRe, (m) => '(${m.group(1)})/(${m.group(2)})');
  }

  // \sqrt{x} -> √(x), \sqrt[n]{x} -> ⁿ√(x)
  t = t.replaceAllMapped(
    RegExp(r'\\sqrt\[([^\[\]]*)\]\{([^{}]*)\}'),
    (m) => '${m.group(1)}√(${m.group(2)})',
  );
  t = t.replaceAllMapped(
    RegExp(r'\\sqrt\{([^{}]*)\}'),
    (m) => '√(${m.group(1)})',
  );

  // Superscripts: x^{ab} -> x^(ab); x^2 -> x² when every char has a
  // unicode superscript, else leave as x^(2).
  t = t.replaceAllMapped(RegExp(r'\^\{([^{}]*)\}'), (m) {
    final inner = m.group(1)!;
    if (inner.split('').every((c) => _superscriptDigits.containsKey(c))) {
      return inner.split('').map((c) => _superscriptDigits[c]).join();
    }
    return '^($inner)';
  });
  t = t.replaceAllMapped(RegExp(r'\^([A-Za-z0-9])'), (m) {
    final c = m.group(1)!;
    return _superscriptDigits[c] ?? '^$c';
  });

  // Subscripts: just parenthesise — there's no compact unicode fallback
  // for most subscripted variables.
  t = t.replaceAllMapped(RegExp(r'_\{([^{}]*)\}'), (m) => '_(${m.group(1)})');

  // \sum_{a}^{b} / \int_{a}^{b} -> "sum from a to b of" / "integral from a to b of"
  t = t.replaceAllMapped(
    RegExp(r'\\sum_\{([^{}]*)\}\^\{([^{}]*)\}'),
    (m) => 'sum from ${m.group(1)} to ${m.group(2)} of ',
  );
  t = t.replaceAll(r'\sum', 'Σ');
  t = t.replaceAllMapped(
    RegExp(r'\\int_\{([^{}]*)\}\^\{([^{}]*)\}'),
    (m) => 'integral from ${m.group(1)} to ${m.group(2)} of ',
  );
  t = t.replaceAll(r'\int', '∫');

  // Known symbol/greek-letter vocabulary.
  _latexSymbolWords.forEach((k, v) => t = t.replaceAll(k, v));

  // Matrices: give the student a readable label rather than raw
  // \begin{bmatrix}...\end{bmatrix} source.
  t = t.replaceAllMapped(
    RegExp(r'\\begin\{[a-zA-Z]*matrix\}([\s\S]*?)\\end\{[a-zA-Z]*matrix\}'),
    (m) {
      final rows = m.group(1)!
          .split(r'\\')
          .map((r) => r.trim().replaceAll('&', ', '))
          .where((r) => r.isNotEmpty)
          .map((r) => '[$r]')
          .join(' ');
      return rows.isEmpty ? 'matrix' : rows;
    },
  );

  // Any remaining unrecognised \command{...} — drop the backslash/braces
  // rather than showing broken markup, keeping the argument text readable.
  t = t.replaceAllMapped(
    RegExp(r'\\[a-zA-Z]+\{([^{}]*)\}'),
    (m) => m.group(1)!,
  );
  t = t.replaceAll(RegExp(r'\\[a-zA-Z]+'), '');
  t = t.replaceAll(RegExp(r'[{}]'), '');

  return t.trim();
}

class _MathFallback extends StatelessWidget {
  final String content;
  final bool isDark;
  const _MathFallback({required this.content, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Phase 2, Part 5 — KaTeX failed to render this expression, but the
    // student should still see something they can read, not a dead-end
    // error notice. _readableMathFallbackText() converts the common LaTeX
    // vocabulary to plain readable text (fractions, roots, super/
    // subscripts, greek letters, matrices); if that conversion still
    // produces something clearly broken (empty, or still full of raw
    // backslashes it couldn't resolve), fall back to the short notice
    // rather than showing broken markup.
    final readable = _readableMathFallbackText(content);
    final looksClean = readable.isNotEmpty && !readable.contains(r'\');

    if (looksClean) {
      return Text(
        readable,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white.withOpacity(0.85) : Colors.black87,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 14,
            color: (isDark ? Colors.white60 : Colors.black45)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'This expression could not be displayed',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
      ],
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
// A token that's unambiguously part of a math expression when it sits next
// to a bare LaTeX command: the command itself, a short alphanumeric token
// that contains at least one digit (row/variable labels like "R1", "2R2",
// "x1"), or a run of bare operator characters. Deliberately excludes plain
// multi-letter English words (which never contain digits), so expansion
// stops cleanly at the surrounding sentence text.
final RegExp _mathyTokenCore = RegExp(
  r'^(\\[a-zA-Z]+(\{[^{}]*\})*'
  r'|(?=[A-Za-z0-9]{1,7}$)(?=[A-Za-z0-9]*\d)[A-Za-z0-9]+'
  r'|[+\-=<>*/^_]+)$',
);
final RegExp _trailingPunct = RegExp(r'[.,;:!?]+$');
final RegExp _leadingPunct  = RegExp(r'^[(\[]+');

/// Tests a raw whitespace-delimited word against [_mathyTokenCore] after
/// stripping sentence punctuation stuck to it (e.g. "3.", "\infty,") so
/// trailing/leading punctuation doesn't block an otherwise-valid expansion.
bool _isMathyWord(String word) {
  final core = word.replaceFirst(_trailingPunct, '').replaceFirst(_leadingPunct, '');
  if (core.isEmpty) return false;
  return _mathyTokenCore.hasMatch(core);
}

/// Wraps bare/undelimited LaTeX command runs — e.g. "R1 \rightarrow R2" or
/// "x \leq 5" typed with NO `$` anywhere — in `$...$` so they render as math
/// instead of leaking as raw LaTeX text. Runs BEFORE every other
/// preprocessing step, and skips any text already inside an existing
/// `$...$`/`$$...$$` span so nothing is ever double-wrapped.
String _wrapBareLatexRuns(String text) {
  if (!text.contains(r'\')) return text;   // fast path: no backslash, nothing to do

  final protected = <List<int>>[];
  for (final m in RegExp(r'\$\$[\s\S]*?\$\$|\$(?:[^\$\n]|\\.)+?\$').allMatches(text)) {
    protected.add([m.start, m.end]);
  }
  bool isProtected(int pos) => protected.any((p) => pos >= p[0] && pos < p[1]);

  final words = RegExp(r'\S+').allMatches(text).toList();
  if (words.isEmpty) return text;

  final spansToWrap = <List<int>>[];   // word-index [startIdx, endIdx] inclusive
  int i = 0;
  while (i < words.length) {
    final w = words[i].group(0)!;
    if (w.startsWith(r'\') &&
        RegExp(r'^\\[a-zA-Z]+').hasMatch(w) &&
        !isProtected(words[i].start)) {
      int left = i;
      while (left - 1 >= 0 &&
          !isProtected(words[left - 1].start) &&
          _isMathyWord(words[left - 1].group(0)!)) {
        left--;
      }
      int right = i;
      while (right + 1 < words.length &&
          !isProtected(words[right + 1].start) &&
          _isMathyWord(words[right + 1].group(0)!)) {
        right++;
      }
      spansToWrap.add([left, right]);
      i = right + 1;
    } else {
      i++;
    }
  }
  if (spansToWrap.isEmpty) return text;

  final buffer = StringBuffer();
  int lastEnd = 0;
  for (final span in spansToWrap) {
    final startChar = words[span[0]].start;
    final endChar   = words[span[1]].end;
    buffer.write(text.substring(lastEnd, startChar));
    buffer.write(r'$');
    buffer.write(text.substring(startChar, endChar));
    buffer.write(r'$');
    lastEnd = endChar;
  }
  buffer.write(text.substring(lastEnd));
  return buffer.toString();
}

/// Wraps bare caret-exponent expressions that contain NO backslash at all —
/// e.g. "3x^2", "(x+1)^2", "e^{-x}", "x^n" typed with no `$` anywhere.
///
/// Root cause (Phase 2, Part 5): [_wrapBareLatexRuns] above only fires when
/// a LaTeX command (a backslash) is present. A caret exponent has no
/// backslash, so "3x^2" never entered the math pipeline at all and rendered
/// as literal text with a visible "^" instead of a superscript — exactly
/// the "3x^2 / (x+1)^2 instead of proper mathematical notation" symptom.
/// Deliberately conservative: only matches an actual `base^exponent` shape
/// (a caret is essentially never meaningful in ordinary prose), so this
/// never touches other text.
final RegExp _caretExprRe = RegExp(
  r'(?:[A-Za-z0-9]|\([^()\n]{1,40}\))+\^(?:\{[^{}\n]{1,40}\}|[+\-]?[A-Za-z0-9]+)',
);

String _wrapBareCaretExpressions(String text) {
  if (!text.contains('^')) return text;   // fast path

  final protected = <List<int>>[];
  for (final m in RegExp(r'\$\$[\s\S]*?\$\$|\$(?:[^\$\n]|\\.)+?\$').allMatches(text)) {
    protected.add([m.start, m.end]);
  }
  bool isProtected(int pos) => protected.any((p) => pos >= p[0] && pos < p[1]);

  final buffer = StringBuffer();
  int lastEnd = 0;
  for (final m in _caretExprRe.allMatches(text)) {
    if (isProtected(m.start)) continue;
    buffer.write(text.substring(lastEnd, m.start));
    buffer.write(r'$');
    buffer.write(m.group(0));
    buffer.write(r'$');
    lastEnd = m.end;
  }
  buffer.write(text.substring(lastEnd));
  return buffer.toString();
}

String _preprocess(String text) {
  // Step -1: wrap bare caret-exponent expressions with NO backslash at all
  // (e.g. "3x^2", "(x+1)^2") — see _wrapBareCaretExpressions() docstring.
  // Runs before Step 0 so its inserted $ pairs are correctly treated as
  // already-protected by the backslash-run wrapper below.
  text = _wrapBareCaretExpressions(text);

  // Step 0: wrap bare LaTeX command runs with no $ at all (arrows, greek
  // letters, operators typed standalone — e.g. row-operation instructions
  // like "R1 \rightarrow R1 - 2R2") so they never leak as raw text.
  text = _wrapBareLatexRuns(text);

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
