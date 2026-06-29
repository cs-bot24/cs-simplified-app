// lib/widgets/ai_streaming_renderer.dart
//
// Renders a complete AI response (JSON block format or legacy markdown)
// as ONE static widget tree inside the caller's message bubble.
//
// IMPORTANT — Scrolling architecture:
//   This widget intentionally does NOT reveal blocks one at a time and
//   does NOT mutate its own widget count over time. The previous
//   implementation used a Future.delayed/setState loop to fade blocks in
//   one after another, which kept changing this widget's height every
//   30-120ms. Because this widget lives inside the single chat
//   ListView.builder, every one of those height changes re-ran layout
//   for the scrolling list and could yank the viewport out from under
//   a user who was mid-drag reading an older message. ChatGPT-style
//   chat lists render each message's content once into a single
//   widget; do not reintroduce progressive block reveal here.
//
//   The only animation that remains is a single, one-shot fade-in of
//   the *entire* message body (see _FadeInOnce). That animation does
//   not change layout size at any point, so it never fights user
//   scroll gestures or auto-scroll logic.
//
// Usage:
//   AiStreamingRenderer(content: jsonString, isDark: true)
//
// Falls back to AiContentRenderer's legacy markdown path for non-JSON
// responses (handled here via AiMessageContent).

import 'package:flutter/material.dart';
import '../models/ai_block.dart';
import 'ai_block_renderer.dart';
import 'ai_message_content.dart';

class AiStreamingRenderer extends StatefulWidget {
  final String              content;
  final bool?               isDark;
  final EdgeInsetsGeometry? padding;
  final VoidCallback?       onComplete;

  const AiStreamingRenderer({
    super.key,
    required this.content,
    this.isDark,
    this.padding,
    this.onComplete,
  });

  @override
  State<AiStreamingRenderer> createState() => _AiStreamingRendererState();
}

class _AiStreamingRendererState extends State<AiStreamingRenderer> {
  AiJsonResponse? _parsed;
  bool            _isLegacy = false;
  bool            _completedCalled = false;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(AiStreamingRenderer old) {
    super.didUpdateWidget(old);
    // Only re-parse if the underlying content actually changed (e.g. the
    // provider replaced this message). Re-parsing on every rebuild would
    // pointlessly rebuild the whole block tree.
    if (old.content != widget.content) {
      _parsed = null;
      _isLegacy = false;
      _completedCalled = false;
      _parse();
    }
  }

  void _parse() {
    final parsed = AiJsonResponse.tryParse(widget.content);

    if (parsed == null || parsed.isEmpty) {
      _isLegacy = true;
    } else {
      _parsed = parsed;
    }

    // The full response is already in memory (the backend does not stream
    // partial JSON to this widget), so parsing — and therefore "reveal" —
    // completes synchronously and exactly once.
    if (!_completedCalled) {
      _completedCalled = true;
      // Defer to after this frame so callers that call setState() in
      // onComplete (e.g. to trigger a scroll) never do so mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onComplete?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDark ?? (Theme.of(context).brightness == Brightness.dark);

    Widget child;
    if (_isLegacy) {
      child = AiMessageContent(data: widget.content, isDark: dark);
    } else if (_parsed == null) {
      // Should not normally happen (parsing is synchronous), but keep a
      // lightweight, static placeholder just in case.
      child = const _BlockSkeleton();
    } else {
      // Single render pass: every block goes into the SAME widget tree at
      // once. No staggered children, no per-block AnimationControllers.
      child = AiBlockRenderer(blocks: _parsed!.blocks, isDark: dark);
    }

    if (widget.padding != null) {
      child = Padding(padding: widget.padding!, child: child);
    }

    // One-shot fade-in for the whole message. Fixed duration, fixed final
    // size from frame one — this never changes the message's height.
    return _FadeInOnce(key: ValueKey(widget.content), child: child);
  }
}

// ── One-shot fade-in (no layout change, no repeated triggers) ────────────────

class _FadeInOnce extends StatefulWidget {
  final Widget child;
  const _FadeInOnce({super.key, required this.child});

  @override
  State<_FadeInOnce> createState() => _FadeInOnceState();
}

class _FadeInOnceState extends State<_FadeInOnce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _fade, child: widget.child);
}

// ── Loading skeleton (static, used only before first paint) ──────────────────

class _BlockSkeleton extends StatefulWidget {
  const _BlockSkeleton();
  @override
  State<_BlockSkeleton> createState() => _BlockSkeletonState();
}

class _BlockSkeletonState extends State<_BlockSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? Colors.white : Colors.black;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeletonLine(base, _anim.value, 0.85),
          const SizedBox(height: 6),
          _skeletonLine(base, _anim.value, 0.7),
          const SizedBox(height: 6),
          _skeletonLine(base, _anim.value, 0.5),
        ],
      ),
    );
  }

  Widget _skeletonLine(Color base, double opacity, double widthFactor) =>
      FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height:       12,
          decoration:   BoxDecoration(
            color:        base.withOpacity(opacity * 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      );
}

// ── Typing indicator (standalone, reusable) ───────────────────────────────────
//
// This is the "AI is thinking" dot animation shown BEFORE any message
// content exists (i.e. as the loading placeholder item appended after the
// last message, never as part of an actual message's content). It is a
// fixed-size widget — it does not grow, shrink, or add/remove children —
// so it never affects scroll position by itself.

class AiTypingIndicator extends StatefulWidget {
  final bool isDark;
  const AiTypingIndicator({super.key, this.isDark = true});

  @override
  State<AiTypingIndicator> createState() => _AiTypingIndicatorState();
}

class _AiTypingIndicatorState extends State<AiTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isDark
        ? Colors.white.withOpacity(0.6)
        : Colors.black.withOpacity(0.4);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => _Dot(
        controller: _ctrl,
        delay:      i * 0.2,
        color:      color,
      )),
    );
  }
}

class _Dot extends StatelessWidget {
  final AnimationController controller;
  final double              delay;
  final Color               color;

  const _Dot({
    required this.controller,
    required this.delay,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final anim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 1),
      TweenSequenceItem(tween: ConstantTween(0.0),            weight: 4),
    ]).animate(CurvedAnimation(
      parent: controller,
      curve:  Interval(delay, (delay + 0.35).clamp(0, 1.0),
          curve: Curves.easeInOut),
    ));

    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, anim.value),
        child:  Container(
          width:  7, height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
