import 'dart:convert';

import 'package:flutter/material.dart';
import '../models/ai_block.dart';
import 'ai_streaming_renderer.dart';
import 'ai_message_content.dart';

class AiContentRenderer extends StatelessWidget {
  final String              content;
  final bool?               isDark;
  final bool                selectable;
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

    // ── Attempt 1: clean parse ────────────────────────────────────────────────
    final parsed = AiJsonResponse.tryParse(content);
    if (parsed != null && !parsed.isEmpty) {
      return AiStreamingRenderer(
        content: content,
        isDark:  dark,
        padding: padding,
      );
    }

    // ── Attempt 2: repair then parse ─────────────────────────────────────────
    // Handles cases where the model wraps JSON in ```json...``` fences,
    // adds trailing commas, or prefixes prose before the opening brace.
    final repaired = _tryRepairJson(content);
    if (repaired != null) {
      final parsedRepaired = AiJsonResponse.tryParse(repaired);
      if (parsedRepaired != null && !parsedRepaired.isEmpty) {
        return AiStreamingRenderer(
          content: repaired,
          isDark:  dark,
          padding: padding,
        );
      }
    }

    // ── Attempt 3: extract text from partial JSON ─────────────────────────────
    // If the string looks like it contains JSON blocks but is broken,
    // extract all "content"/"text" string values and render as markdown.
    // This ensures the user always sees readable text, never raw JSON.
    if (_looksLikeJson(content)) {
      final extracted = _extractTextFromBrokenJson(content);
      if (extracted != null && extracted.trim().isNotEmpty) {
        Widget child = AiMessageContent(data: extracted, isDark: dark);
        if (padding != null) child = Padding(padding: padding!, child: child);
        return child;
      }
    }

    // ── Fallback: legacy markdown renderer ───────────────────────────────────
    Widget child = AiMessageContent(data: content, isDark: dark);
    if (padding != null) child = Padding(padding: padding!, child: child);
    return child;
  }

  /// Returns true if the string appears to be intended as JSON
  /// (starts with { or contains "blocks": pattern).
  static bool _looksLikeJson(String s) {
    final t = s.trim();
    return t.startsWith('{') || t.contains('"blocks"') || t.contains('```json');
  }

  /// Attempts common JSON repairs:
  /// - Strip ```json ... ``` fences
  /// - Extract the first {...} object if prose precedes it
  /// - Remove trailing commas before ] or }
  static String? _tryRepairJson(String raw) {
    String s = raw.trim();

    // Strip markdown code fences
    final fenceRe = RegExp(r'```(?:json)?\s*([\s\S]*?)```', multiLine: true);
    final fenceMatch = fenceRe.firstMatch(s);
    if (fenceMatch != null) {
      s = fenceMatch.group(1)?.trim() ?? s;
    }

    // Extract first { ... } block if prose precedes it
    final braceStart = s.indexOf('{');
    if (braceStart > 0) {
      s = s.substring(braceStart);
    }

    if (!s.startsWith('{')) return null;

    // Remove trailing commas before ] or }
    s = s.replaceAll(RegExp(r',\s*([}\]])'), r'$1');

    // Attempt to find balanced closing brace
    try {
      jsonDecode(s); // validate
      return s;
    } catch (_) {
      // Try truncating at the last complete block
      final lastBrace = s.lastIndexOf('}');
      if (lastBrace > 0) {
        final truncated = '${s.substring(0, lastBrace + 1)}';
        try {
          jsonDecode(truncated);
          return truncated;
        } catch (_) {}
      }
    }
    return null;
  }

  /// Last-resort: extract all string values from "text", "content", "term",
  /// "title" keys in broken JSON and join them as readable markdown.
  static String? _extractTextFromBrokenJson(String raw) {
    final results = <String>[];
    final re = RegExp(
      r'"(?:text|content|term|title|items)"\s*:\s*(?:"((?:[^"\\]|\\.)*)"|(\[[^\]]*\]))',
      multiLine: true,
    );
    for (final m in re.allMatches(raw)) {
      final str   = m.group(1);
      final arr   = m.group(2);
      if (str != null && str.trim().isNotEmpty) {
        results.add(str
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\"', '"')
            .trim());
      } else if (arr != null) {
        // Parse simple string arrays
        final itemRe = RegExp(r'"((?:[^"\\]|\\.)*)"');
        for (final im in itemRe.allMatches(arr)) {
          final item = im.group(1);
          if (item != null && item.trim().isNotEmpty) {
            results.add('• ${item.replaceAll(r'\n', '\n').trim()}');
          }
        }
      }
    }
    return results.isEmpty ? null : results.join('\n\n');
  }
}
