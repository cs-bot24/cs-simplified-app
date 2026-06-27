// lib/widgets/ai_streaming_renderer.dart — Phase 3: Progressive Block Reveal
//
// Renders AI JSON responses with a progressive reveal animation.
// Each block fades and slides in one after another, giving the feel
// of streaming even when the full response arrives at once.
//
// Usage:
//   AiStreamingRenderer(content: jsonString, isDark: true)
//
// Falls back to AiContentRenderer for legacy markdown responses.

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
  int             _visibleCount = 0;
  bool            _isLegacy     = false;

  // Stagger delay per block — faster for more blocks
  Duration get _staggerDelay {
    final count = _parsed?.blocks.length ?? 0;
    if (count <= 3)  return const Duration(milliseconds: 120);
    if (count <= 8)  return const Duration(milliseconds: 80);
    if (count <= 15) return const Duration(milliseconds: 50);
    return const Duration(milliseconds: 30);
  }

  @override
  void initState() {
    super.initState();
    _parseAndReveal();
  }

  @override
  void didUpdateWidget(AiStreamingRenderer old) {
    super.didUpdateWidget(old);
    if (old.content != widget.content) {
      _parsed       = null;
      _visibleCount = 0;
      _isLegacy     = false;
      _parseAndReveal();
    }
  }

  void _parseAndReveal() {
    final parsed = AiJsonResponse.tryParse(widget.content);

    if (parsed == null || parsed.isEmpty) {
      // Legacy markdown — render immediately
      if (mounted) setState(() => _isLegacy = true);
      widget.onComplete?.call();
      return;
    }

    _parsed       = parsed;
    _visibleCount = 0;

    // Reveal blocks one at a time
    _revealNext();
  }

  void _revealNext() {
    if (!mounted) return;
    if (_parsed == null) return;
    if (_visibleCount >= _parsed!.blocks.length) {
      widget.onComplete?.call();
      return;
    }

    Future.delayed(_staggerDelay, () {
      if (!mounted) return;
      setState(() => _visibleCount++);
      _revealNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDark ?? (Theme.of(context).brightness == Brightness.dark);

    // Legacy fallback
    if (_isLegacy) {
      Widget child = AiMessageContent(data: widget.content, isDark: dark);
      if (widget.padding != null) {
        child = Padding(padding: widget.padding!, child: child);
      }
      return child;
    }

    // JSON not yet parsed
    if (_parsed == null) {
      return const _BlockSkeleton();
    }

    // Progressive reveal
    final visibleBlocks = _parsed!.blocks.take(_visibleCount).toList();
    final allVisible    = _visibleCount >= _parsed!.blocks.length;

    Widget child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < visibleBlocks.length; i++) ...[
          _AnimatedBlock(
            key:   ValueKey('block_$i'),
            block: visibleBlocks[i],
            dark:  dark,
          ),
          if (i < visibleBlocks.length - 1) const SizedBox(height: 10),
        ],
        // Show skeleton for next block if still revealing
        if (!allVisible && visibleBlocks.isNotEmpty) ...[
          const SizedBox(height: 10),
          const _BlockSkeleton(),
        ],
      ],
    );

    if (widget.padding != null) {
      child = Padding(padding: widget.padding!, child: child);
    }

    return child;
  }
}

// ── Animated single block ─────────────────────────────────────────────────────

class _AnimatedBlock extends StatefulWidget {
  final AiBlock block;
  final bool    dark;
  const _AnimatedBlock({super.key, required this.block, required this.dark});

  @override
  State<_AnimatedBlock> createState() => _AnimatedBlockState();
}

class _AnimatedBlockState extends State<_AnimatedBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 300),
    );
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(
      position: _slide,
      child: AiBlockRenderer(
        blocks: [widget.block],
        isDark: widget.dark,
      ),
    ),
  );
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

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
    final dark   = Theme.of(context).brightness == Brightness.dark;
    final base   = dark ? Colors.white : Colors.black;

    return AnimatedBuilder(
      animation: _anim,
      builder:   (_, __) => Column(
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
