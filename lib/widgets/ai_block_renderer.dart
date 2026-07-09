// lib/widgets/ai_block_renderer.dart — Block Renderer
//
// Renders a list of AiBlock objects into a SINGLE static widget tree
// (one Column, built once). Each block type has its own dedicated
// widget, but all blocks for a message are laid out together in one
// pass — there is no progressive/staggered reveal here. That keeps the
// height of one chat bubble stable from the first frame it appears,
// which is required for the single-ListView chat scrolling architecture
// to work (see ai_streaming_renderer.dart for the rationale).
//
// NO raw markdown or LaTeX ever appears to the user.
//
// Note on horizontal SingleChildScrollViews used below (for wide code
// blocks, tables, and matrices): these scroll sideways only and live
// fully inside a block's fixed-height container, so they never compete
// with the chat list's vertical scroll gesture.
//
// Usage:
//   AiBlockRenderer(blocks: response.blocks)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../models/ai_block.dart';
import 'mermaid_diagram.dart';

// ── App colours (keep in sync with AppTheme) ─────────────────────────────────
const _kPrimary   = Color(0xFF1A3C6E);
const _kAccent    = Color(0xFF5B9BD5);
const _kGreen     = Color(0xFF16A34A);
const _kOrange    = Color(0xFFEA580C);
const _kPurple    = Color(0xFF7C3AED);
const _kTeal      = Color(0xFF0D9488);
const _kRed       = Color(0xFFDC2626);

// ════════════════════════════════════════════════════════════════════════════
// TOP-LEVEL RENDERER
// ════════════════════════════════════════════════════════════════════════════

class AiBlockRenderer extends StatelessWidget {
  final List<AiBlock> blocks;
  final bool?         isDark;
  final EdgeInsetsGeometry? padding;

  const AiBlockRenderer({
    super.key,
    required this.blocks,
    this.isDark,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final widgets = blocks
        .where((b) => b.type != AiBlockType.unknown)
        .map((b) => _buildBlock(b, dark, context))
        .toList();

    Widget child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < widgets.length; i++) ...[
          widgets[i],
          if (i < widgets.length - 1) const SizedBox(height: 10),
        ],
      ],
    );

    if (padding != null) {
      child = Padding(padding: padding!, child: child);
    }
    return child;
  }

  Widget _buildBlock(AiBlock b, bool dark, BuildContext context) {
    switch (b.type) {
      case AiBlockType.heading:      return _HeadingCard(block: b, dark: dark);
      case AiBlockType.text:         return _TextCard(block: b, dark: dark);
      case AiBlockType.math:         return _MathCard(block: b, dark: dark);
      case AiBlockType.matrix:       return _MatrixCard(block: b, dark: dark);
      case AiBlockType.code:         return _CodeCard(block: b, dark: dark);
      case AiBlockType.definition:   return _DefinitionCard(block: b, dark: dark);
      case AiBlockType.theorem:      return _TheoremCard(block: b, dark: dark);
      case AiBlockType.proof:        return _ProofCard(block: b, dark: dark);
      case AiBlockType.example:      return _ExampleCard(block: b, dark: dark);
      case AiBlockType.exercise:     return _ExerciseCard(block: b, dark: dark);
      case AiBlockType.solution:     return _SolutionCard(block: b, dark: dark);
      case AiBlockType.warning:      return _WarningCard(block: b, dark: dark);
      case AiBlockType.tip:          return _TipCard(block: b, dark: dark);
      case AiBlockType.quote:        return _QuoteCard(block: b, dark: dark);
      case AiBlockType.bulletList:   return _BulletListCard(block: b, dark: dark);
      case AiBlockType.numberedList: return _NumberedListCard(block: b, dark: dark);
      case AiBlockType.table:        return _TableCard(block: b, dark: dark);
      case AiBlockType.diagram:      return _DiagramCard(block: b, dark: dark);
      case AiBlockType.divider:      return _DividerCard(dark: dark);
      default:                       return const SizedBox.shrink();
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED UTILITIES
// ════════════════════════════════════════════════════════════════════════════

Color _textColor(bool dark) =>
    dark ? Colors.white.withOpacity(0.92) : const Color(0xFF1E293B);

Color _subTextColor(bool dark) =>
    dark ? Colors.white.withOpacity(0.6) : const Color(0xFF64748B);

Color _cardBg(bool dark, Color accent) => accent.withOpacity(dark ? 0.12 : 0.07);

TextStyle _bodyStyle(bool dark, {double size = 14.5}) => TextStyle(
  color:  _textColor(dark),
  fontSize: size,
  height: 1.6,
);

// Matches, across all block-card body text (Definition/Theorem/Proof/Example/
// Solution/Warning/Tip cards, bullet lists, table cells, plain paragraphs):
//   1: $$...$$          (display)
//   2: \[...\]          (display)
//   3: \(...\)          (inline)
//   4: $...$            (inline)
//   5/6: bare \begin{ENV}...\end{ENV} with NO surrounding delimiters at all
//        (ENV backreferenced via \5 so \begin{bmatrix}...\end{pmatrix} can't
//        mismatch) — this bare-environment case is what previously fell
//        straight through to a raw, unrendered Text() below.
final RegExp _mathSpanRegex = RegExp(
  r'\$\$([\s\S]+?)\$\$'
  r'|\\\[([\s\S]+?)\\\]'
  r'|\\\(([\s\S]+?)\\\)'
  r'|\$((?:[^$\\]|\\.)+?)\$'
  r'|\\begin\{(matrix|bmatrix|pmatrix|vmatrix|Bmatrix|Vmatrix|smallmatrix|cases|aligned|align\*?|gathered|array)\}([\s\S]+?)\\end\{\5\}',
);

bool _looksLikeItMightContainMath(String text) =>
    text.contains(r'$') || text.contains(r'\[') || text.contains(r'\(') || text.contains(r'\begin{');

// Renders inline text with embedded math in ANY of the forms above.
Widget _inlineText(String text, bool dark, {double size = 14.5}) {
  if (!_looksLikeItMightContainMath(text)) {
    return Text(text, style: _bodyStyle(dark, size: size));
  }

  final parts = <InlineSpan>[];
  int   last  = 0;

  for (final match in _mathSpanRegex.allMatches(text)) {
    if (match.start > last) {
      parts.add(TextSpan(
        text: text.substring(last, match.start),
        style: _bodyStyle(dark, size: size),
      ));
    }

    String latex;
    bool   display;
    if (match.group(1) != null) {
      latex = match.group(1)!;   display = true;                    // $$...$$
    } else if (match.group(2) != null) {
      latex = match.group(2)!;   display = true;                    // \[...\]
    } else if (match.group(3) != null) {
      latex = match.group(3)!;   display = false;                   // \(...\)
    } else if (match.group(5) != null) {
      latex = '\\begin{${match.group(5)}}${match.group(6)}\\end{${match.group(5)}}';
      display = true;                                                // bare \begin{...}
    } else {
      latex = match.group(4) ?? ''; display = false;                 // $...$
    }

    parts.add(WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Math.tex(
        latex,
        mathStyle: display ? MathStyle.display : MathStyle.text,
        textStyle: TextStyle(fontSize: size, color: _textColor(dark)),
        onErrorFallback: (e) => Text(
          '⚠ math expression unavailable',
          style: TextStyle(fontSize: size * 0.9, fontStyle: FontStyle.italic,
              color: _textColor(dark).withOpacity(0.6)),
        ),
      ),
    ));
    last = match.end;
  }

  if (last < text.length) {
    parts.add(TextSpan(
      text: text.substring(last),
      style: _bodyStyle(dark, size: size),
    ));
  }

  return Text.rich(TextSpan(children: parts));
}

// Matches fenced code blocks (```lang\n...\n```) embedded directly inside
// otherwise-plain card text — e.g. a "Solution" or worked "Example" card
// where the model wrote out Java/Python/etc. code as part of its narrative
// instead of emitting a separate CODE block. Without this, that code would
// flow through _inlineText as one run-on paragraph with no monospace font,
// no line breaks, and no copy button — exactly the "all in one line, hard
// to read" bug this exists to fix.
final RegExp _fencedCodeRegex = RegExp(r'```([a-zA-Z0-9_+-]*)\n?([\s\S]*?)```');

/// Renders card body text that may contain one or more fenced code blocks
/// mixed in with plain narrative text. Plain segments still go through
/// _inlineText (so bare/inline math keeps rendering); code segments get the
/// same proper code-block treatment as a dedicated CODE block.
Widget _richContent(String content, bool dark, {double size = 14.5}) {
  if (!content.contains('```')) {
    return _inlineText(content, dark, size: size);
  }

  final children = <Widget>[];
  int last = 0;
  for (final m in _fencedCodeRegex.allMatches(content)) {
    if (m.start > last) {
      final before = content.substring(last, m.start).trim();
      if (before.isNotEmpty) {
        children.add(_inlineText(before, dark, size: size));
        children.add(const SizedBox(height: 8));
      }
    }
    final lang = (m.group(1) ?? '').trim();
    final code = (m.group(2) ?? '').trimRight();
    if (code.trim().isNotEmpty) {
      children.add(_InlineCodeBlock(content: code, language: lang, dark: dark));
      children.add(const SizedBox(height: 8));
    }
    last = m.end;
  }
  if (last < content.length) {
    final after = content.substring(last).trim();
    if (after.isNotEmpty) {
      children.add(_inlineText(after, dark, size: size));
    }
  }
  if (children.isNotEmpty && children.last is SizedBox) {
    children.removeLast();
  }
  if (children.isEmpty) {
    // Fell through without producing anything usable (e.g. content was
    // only a stray/unterminated fence) — fall back to plain rendering
    // rather than showing a blank card.
    return _inlineText(content, dark, size: size);
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
}

/// Same visual treatment as _CodeCard (header bar with language label + copy
/// button, monospace body, horizontal scroll for long lines), but takes
/// plain content/language instead of an AiBlock — used by _richContent for
/// code fences discovered embedded inside another card's text.
class _InlineCodeBlock extends StatelessWidget {
  final String content;
  final String language;
  final bool   dark;
  const _InlineCodeBlock({required this.content, required this.language, required this.dark});

  @override
  Widget build(BuildContext context) {
    final bgColor = dark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final txColor = dark ? const Color(0xFFE6EDF3) : const Color(0xFF24292F);

    return Container(
      width:      double.infinity,
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.15))),
            ),
            child: Row(children: [
              Text(
                language.isNotEmpty ? language : 'code',
                style: TextStyle(fontSize: 11, color: Colors.grey.withOpacity(0.7),
                    fontFamily: 'monospace'),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Clipboard.setData(ClipboardData(text: content)),
                child: Icon(Icons.copy_rounded, size: 14, color: Colors.grey.withOpacity(0.6)),
              ),
            ]),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            child: Text(
              content,
              style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: txColor, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// Safe math render with fallback
Widget _mathWidget(String latex, bool dark, {bool display = true, double size = 15}) {
  if (latex.isEmpty) return const SizedBox.shrink();
  return Math.tex(
    latex,
    mathStyle: display ? MathStyle.display : MathStyle.text,
    textStyle: TextStyle(fontSize: size, color: _textColor(dark)),
    onErrorFallback: (e) {
      // Never show the raw LaTeX source to the user — just a clean,
      // visually consistent "couldn't render this" notice.
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _kRed.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _kRed.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 14, color: _kRed.withOpacity(0.8)),
            const SizedBox(width: 6),
            Text(
              'This expression could not be displayed',
              style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic,
                  color: _kRed.withOpacity(0.8)),
            ),
          ],
        ),
      );
    },
  );
}

// ════════════════════════════════════════════════════════════════════════════
// BLOCK WIDGETS
// ════════════════════════════════════════════════════════════════════════════

// ── Heading ──────────────────────────────────────────────────────────────────

class _HeadingCard extends StatelessWidget {
  final AiBlock block;
  final bool    dark;
  const _HeadingCard({required this.block, required this.dark});

  @override
  Widget build(BuildContext context) {
    final sizes  = {1: 22.0, 2: 18.0, 3: 15.5, 4: 14.0};
    final size   = sizes[block.level] ?? 16.0;
    final weight = block.level <= 2 ? FontWeight.w800 : FontWeight.w700;

    return Padding(
      padding: EdgeInsets.only(
        top:    block.level <= 2 ? 8 : 4,
        bottom: 4,
      ),
      child: _inlineText(block.text, dark, size: size),
    );
  }
}

// ── Text ─────────────────────────────────────────────────────────────────────

class _TextCard extends StatelessWidget {
  final AiBlock block;
  final bool    dark;
  const _TextCard({required this.block, required this.dark});

  @override
  Widget build(BuildContext context) =>
      _richContent(block.content, dark);
}

// ── Math ─────────────────────────────────────────────────────────────────────

class _MathCard extends StatelessWidget {
  final AiBlock block;
  final bool    dark;
  const _MathCard({required this.block, required this.dark});

  @override
  Widget build(BuildContext context) {
    if (!block.display) {
      // Inline math embedded in a row
      return Wrap(children: [
        _mathWidget(block.latex, dark, display: false),
      ]);
    }

    return Container(
      width:  double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E2240) : const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _kAccent.withOpacity(dark ? 0.3 : 0.2),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _mathWidget(block.latex, dark, display: true, size: 16),
      ),
    );
  }
}

// ── Matrix ────────────────────────────────────────────────────────────────────

class _MatrixCard extends StatelessWidget {
  final AiBlock block;
  final bool    dark;
  const _MatrixCard({required this.block, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      margin:  const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color:        dark ? const Color(0xFF1A2035) : const Color(0xFFF5F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPrimary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Text(
                block.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kAccent,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _mathWidget(block.latex, dark, display: true, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Code ─────────────────────────────────────────────────────────────────────

class _CodeCard extends StatelessWidget {
  final AiBlock block;
  final bool    dark;
  const _CodeCard({required this.block, required this.dark});

  @override
  Widget build(BuildContext context) {
    final bgColor = dark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final txColor = dark ? const Color(0xFFE6EDF3) : const Color(0xFF24292F);

    return Container(
      width:        double.infinity,
      decoration:   BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.15))),
            ),
            child: Row(children: [
              Text(
                block.language.isNotEmpty ? block.language : 'code',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.withOpacity(0.7),
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Clipboard.setData(ClipboardData(text: block.content)),
                child: Icon(Icons.copy_rounded, size: 14,
                    color: Colors.grey.withOpacity(0.6)),
              ),
            ]),
          ),
          // Code content
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            child: Text(
              block.content,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize:   13,
                color:      txColor,
                height:     1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Definition ────────────────────────────────────────────────────────────────

class _DefinitionCard extends StatelessWidget {
  final AiBlock block;
  final bool    dark;
  const _DefinitionCard({required this.block, required this.dark});

  @override
  Widget build(BuildContext context) => _LabeledCard(
    icon:    Icons.menu_book_rounded,
    color:   _kPrimary,
    label:   block.term.isNotEmpty ? 'Definition: ${block.term}' : 'Definition',
    content: block.content,
    dark:    dark,
  );
}

// ── Theorem ───────────────────────────────────────────────────────────────────

class _TheoremCard extends StatelessWidget {
  final AiBlock block;
  final bool    dark;
  const _TheoremCard({required this.block, required this.dark});

  @override
  Widget build(BuildContext context) => _LabeledCard(
    icon:    Icons.lightbulb_rounded,
    color:   _kPurple,
    label:   block.title.isNotEmpty ? block.title : 'Theorem',
    content: block.content,
    dark:    dark,
  );
}

// ── Proof ─────────────────────────────────────────────────────────────────────

class _ProofCard extends StatelessWidget {
  final AiBlock block;
  final bool    dark;
  const _ProofCard({required this.block, required this.dark});

  @override
  Widget build(BuildContext context) => _LabeledCard(
    icon:    Icons.functions_rounded,
    color:   _kTeal,
    label:   'Proof',
    content: block.content,
    dark:    dark,
  );
}

// ── Example ───────────────────────────────────────────────────────────────────

class _ExampleCard extends StatelessWidget {
  final AiBlock block;
  final bool    dark;
  const _ExampleCard({required this.block, required this.dark});

  @override
  Widget build(BuildContext context) => _LabeledCard(
    icon:    Icons.edit_note_rounded,
    color:   _kGreen,
    label:   block.title.isNotEmpty ? block.title : 'Example',
    content: block.content,
    dark:    dark,
  );
}

// ── Exercise ──────────────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final AiBlock block;
  final bool    dark;
  const _ExerciseCard({required this.block, required this.dark});

  static const _diffColor = {
    'easy':   Color(0xFF16A34A),
    'medium': Color(0xFFEA580C),
    'hard':   Color(0xFFDC2626),
  };

  @override
  Widget build(BuildContext context) {
    final diffColor = _diffColor[block.difficulty] ?? _kOrange;
    final diffLabel = block.difficulty[0].toUpperCase() +
        block.difficulty.substring(1);

    return Container(
      decoration: BoxDecoration(
        color:        _cardBg(dark, _kOrange),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _kOrange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Icon(Icons.quiz_rounded, size: 16, color: _kOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Exercise',
                  style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13, color: _kOrange)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:        diffColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border:       Border.all(color: diffColor.withOpacity(0.3)),
                ),
                child: Text(diffLabel,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: diffColor)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _richContent(block.content, dark),
          ),
        ],
      ),
    );
  }
}

// ── Solution ──────────────────────────────────────────────────────────────────

class _SolutionCard extends StatelessWidget {
  final AiBlock block;
  final bool    dark;
  const _SolutionCard({required this.block, required this.dark});

  @override
  Widget build(BuildContext context) => _LabeledCard(
    icon:    Icons.check_circle_rounded,
    color:   _kGreen,
    label:   'Solution',
    content: block.content,
    dark:    dark,
  );
}

// ── Warning ───────────────────────────────────────────────────────────────────

class _WarningCard extends StatelessWidget {
  final AiBlock block;
  final bool    dark;
  const _WarningCard({required this.block, required this.dark});

  @override
  Widget build(BuildContext context) => _LabeledCard(
    icon:    Icons.warning_amber_rounded,
    color:   _kOrange,
    label:   'Common Mistake',
    content: block.content,
    dark:    dark,
  );
}

// ── Tip ───────────────────────────────────────────────────────────────────────

class _TipCard extends StatelessWidget {
  final AiBlock block;
  final bool    dark;
  const _TipCard({required this.block, required this.dark});

  @override
  Widget build(BuildContext context) => _LabeledCard(
    icon:    Icons.tips_and_updates_rounded,
    color:   _kAccent,
    label:   'Exam Tip',
    content: block.content,
    dark:    dark,
  );
}

// ── Quote ─────────────────────────────────────────────────────────────────────

class _QuoteCard extends StatelessWidget {
  final AiBlock block;
  final bool    dark;
  const _QuoteCard({required this.block, required this.dark});

  @override
  Widget build(BuildContext context) => Container(
    margin:  const EdgeInsets.symmetric(vertical: 2),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: _kAccent.withOpacity(0.6), width: 3),
      ),
      color: _cardBg(dark, _kAccent),
      borderRadius: const BorderRadius.only(
        topRight:    Radius.circular(8),
        bottomRight: Radius.circular(8),
      ),
    ),
    child: _inlineText(block.content, dark),
  );
}

// ── Bullet List ───────────────────────────────────────────────────────────────

class _BulletListCard extends StatelessWidget {
  final AiBlock block;
  final bool    dark;
  const _BulletListCard({required this.block, required this.dark});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: block.items.map((item) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color:  _kAccent,
                shape:  BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: _inlineText(item, dark)),
        ],
      ),
    )).toList(),
  );
}

// ── Numbered List ─────────────────────────────────────────────────────────────

class _NumberedListCard extends StatelessWidget {
  final AiBlock block;
  final bool    dark;
  const _NumberedListCard({required this.block, required this.dark});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: block.items.asMap().entries.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${e.key + 1}.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color:      _kAccent,
                fontSize:   14,
              ),
            ),
          ),
          Expanded(child: _inlineText(e.value, dark)),
        ],
      ),
    )).toList(),
  );
}

// ── Table ─────────────────────────────────────────────────────────────────────

class _TableCard extends StatelessWidget {
  final AiBlock block;
  final bool    dark;
  const _TableCard({required this.block, required this.dark});

  @override
  Widget build(BuildContext context) {
    final borderColor = dark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.08);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Table(
          border:            TableBorder.all(color: borderColor, width: 0.8),
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            // Header row
            TableRow(
              decoration: BoxDecoration(color: _kPrimary.withOpacity(dark ? 0.5 : 0.9)),
              children: block.headers.map((h) => TableCell(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(h,
                    style: const TextStyle(
                      color:      Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize:   13,
                    )),
                ),
              )).toList(),
            ),
            // Data rows
            ...block.rows.asMap().entries.map((e) => TableRow(
              decoration: BoxDecoration(
                color: e.key.isEven
                    ? (dark ? Colors.white.withOpacity(0.03) : Colors.white)
                    : (dark ? Colors.white.withOpacity(0.06) : const Color(0xFFF8FAFF)),
              ),
              children: e.value.map((cell) => TableCell(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: _inlineText(cell, dark, size: 13),
                ),
              )).toList(),
            )),
          ],
        ),
      ),
    );
  }
}

// ── Diagram ───────────────────────────────────────────────────────────────────

class _DiagramCard extends StatefulWidget {
  final AiBlock block;
  final bool    dark;
  const _DiagramCard({required this.block, required this.dark});

  @override
  State<_DiagramCard> createState() => _DiagramCardState();
}

class _DiagramCardState extends State<_DiagramCard> {
  bool _renderError = false;

  @override
  Widget build(BuildContext context) {
    final source = widget.block.source;
    if (source.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label bar
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Icon(Icons.account_tree_rounded, size: 13, color: _kTeal),
              const SizedBox(width: 5),
              Text(
                'Diagram',
                style: TextStyle(
                  fontSize:   11.5,
                  fontWeight: FontWeight.w700,
                  color:      _kTeal,
                ),
              ),
            ],
          ),
        ),

        if (_renderError)
          // Fallback: show source as readable monospace when WebView fails
          _DiagramFallback(source: source, dark: widget.dark)
        else
          MermaidDiagram(
            source: source,
            isDark: widget.dark,
            onError: () {
              if (mounted) setState(() => _renderError = true);
            },
          ),
      ],
    );
  }
}

/// Plain-text fallback shown when Mermaid WebView fails to render.
/// Shows the diagram source in a styled code block so the user
/// can at least read the structure, and offers a copy button.
class _DiagramFallback extends StatelessWidget {
  final String source;
  final bool   dark;
  const _DiagramFallback({required this.source, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        dark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: _kTeal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'mermaid',
                style: TextStyle(
                  fontSize:   11,
                  color:      _kTeal,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Clipboard.setData(ClipboardData(text: source)),
                child: Icon(Icons.copy_rounded, size: 14,
                    color: Colors.grey.withOpacity(0.6)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            source,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize:   12,
              color:      dark ? Colors.white70 : Colors.black54,
              height:     1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Divider ───────────────────────────────────────────────────────────────────

class _DividerCard extends StatelessWidget {
  final bool dark;
  const _DividerCard({required this.dark});

  @override
  Widget build(BuildContext context) => Divider(
    color:     dark ? Colors.white12 : Colors.black12,
    thickness: 1,
    height:    20,
  );
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED LABELED CARD
// ════════════════════════════════════════════════════════════════════════════

class _LabeledCard extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  final String   content;
  final bool     dark;

  const _LabeledCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.content,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color:        _cardBg(dark, color),
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(color: color.withOpacity(0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize:   12.5,
                color:      color,
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: _richContent(content, dark),
        ),
      ],
    ),
  );
}
