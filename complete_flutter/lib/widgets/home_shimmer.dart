import 'package:flutter/material.dart';

/// Skeleton loading state for the home screen.
///
/// Mirrors the approximate shape of the real home content so the layout
/// doesn't jump when data arrives. Uses an animated shimmer effect to
/// indicate that content is on the way.
///
/// Shown only on the very first load when no cached data is available.
/// On subsequent visits the cached data renders instantly and this
/// widget never appears.
class HomeShimmer extends StatefulWidget {
  const HomeShimmer({super.key});

  @override
  State<HomeShimmer> createState() => _HomeShimmerState();
}

class _HomeShimmerState extends State<HomeShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final base = isDark
            ? Colors.white.withOpacity(_anim.value * 0.12)
            : Colors.black.withOpacity(_anim.value * 0.08);

        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exam prep banner placeholder
              _box(base, double.infinity, 88, radius: 18),
              const SizedBox(height: 24),

              // Trending section
              _box(base, 140, 18, radius: 6),
              const SizedBox(height: 12),
              Row(children: [
                _box(base, 160, 120, radius: 16),
                const SizedBox(width: 12),
                _box(base, 160, 120, radius: 16),
                const SizedBox(width: 12),
                _box(base, 160, 120, radius: 16),
              ]),
              const SizedBox(height: 24),

              // Continue reading
              _box(base, 160, 18, radius: 6),
              const SizedBox(height: 12),
              _box(base, double.infinity, 64, radius: 14),
              const SizedBox(height: 10),
              _box(base, double.infinity, 64, radius: 14),
              const SizedBox(height: 24),

              // Quote placeholder
              _box(base, double.infinity, 72, radius: 14),
              const SizedBox(height: 24),

              // Browse by level header
              _box(base, 140, 18, radius: 6),
              const SizedBox(height: 12),
              _box(base, double.infinity, 72, radius: 16),
              const SizedBox(height: 10),
              _box(base, double.infinity, 72, radius: 16),
              const SizedBox(height: 10),
              _box(base, double.infinity, 72, radius: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _box(Color color, double width, double height, {double radius = 8}) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}
