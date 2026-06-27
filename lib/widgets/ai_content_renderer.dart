// lib/widgets/ai_content_renderer.dart — Phase 3: Streaming Renderer
//
// Drop-in replacement for all AI screens.
// Automatically detects JSON (Phase 2) vs legacy markdown (Phase 1).
// JSON responses animate in block by block (progressive reveal).
// Legacy markdown uses AiMessageContent as fallback.
//
// Usage (unchanged from Phase 1 & 2):
//   AiContentRenderer(content: responseString)

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

    // Phase 2/3: structured JSON → progressive block reveal
    final parsed = AiJsonResponse.tryParse(content);
    if (parsed != null && !parsed.isEmpty) {
      return AiStreamingRenderer(
        content: content,
        isDark:  dark,
        padding: padding,
      );
    }

    // Phase 1 fallback: legacy markdown renderer
    Widget child = AiMessageContent(data: content, isDark: dark);
    if (padding != null) {
      child = Padding(padding: padding!, child: child);
    }
    return child;
  }
}
