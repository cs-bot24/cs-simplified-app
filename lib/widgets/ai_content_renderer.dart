// lib/widgets/ai_content_renderer.dart
//
// ─── UNIFIED AI CONTENT RENDERER ───────────────────────────────────────────
//
// This is the SINGLE renderer used by every AI-powered screen in CS Simplified:
//   • AI Tutor        (ai_tutor_screen.dart)
//   • PDF AI          (pdf_web_panels.dart)
//   • Exam Prep       (course_exam_hub_screen.dart)
//   • Quick Revision  (course_exam_hub_screen.dart)
//   • Practice Qs     (course_exam_hub_screen.dart)
//   • AI Lecturer     (ai_lecturer_screen.dart)
//
// No screen may render raw AI text directly. All must use:
//
//   AiContentRenderer(content: responseString)
//
// Internally delegates to AiMessageContent which handles:
//   ✓ Markdown
//   ✓ Inline LaTeX  $...$
//   ✓ Display LaTeX $$...$$
//   ✓ Aligned / matrix / cases environments
//   ✓ Tables
//   ✓ Mermaid diagrams (with error isolation)
//   ✓ Code blocks
//   ✓ Lists & headings
//   ✓ ASCII diagrams (pass-through as code blocks)
//
// Usage:
//   AiContentRenderer(content: aiResponse)
//   AiContentRenderer(content: aiResponse, isDark: true)
//   AiContentRenderer(content: aiResponse, selectable: false)

import 'package:flutter/material.dart';
import 'ai_message_content.dart';

class AiContentRenderer extends StatelessWidget {
  /// The raw AI response string. May contain Markdown, LaTeX, and Mermaid.
  final String content;

  /// When true, uses dark colour scheme (white text on dark background).
  /// Defaults to following the ambient theme brightness.
  final bool? isDark;

  /// Whether text content is selectable. Defaults to true.
  final bool selectable;

  /// Optional extra padding around the rendered content.
  final EdgeInsetsGeometry? padding;

  const AiContentRenderer({
    super.key,
    required this.content,
    this.isDark,
    this.selectable = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);

    Widget child = AiMessageContent(
      data: content,
      isDark: dark,
    );

    if (padding != null) {
      child = Padding(padding: padding!, child: child);
    }

    return child;
  }
}
