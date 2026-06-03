import 'package:flutter/material.dart';

/// Study Streak share card — 360×360 square.
/// Wrap in RepaintBoundary for screenshot capture.
class StreakShareCard extends StatelessWidget {
  final String displayName;
  final int currentStreak;
  final int longestStreak;
  final int totalStudyDays;

  const StreakShareCard({
    super.key,
    required this.displayName,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalStudyDays,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      height: 360,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF8E53), Color(0xFFFFAB40)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Background decorative circles
            Positioned(
              top: -40, right: -40,
              child: _Circle(size: 180, color: Colors.white.withOpacity(0.06)),
            ),
            Positioned(
              bottom: -30, left: -30,
              child: _Circle(size: 140, color: Colors.white.withOpacity(0.06)),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Branding
                  const _BrandingRow(),
                  const Spacer(),
                  // Main streak number
                  Text(
                    '$currentStreak',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 80,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  const Text(
                    'DAY STREAK 🔥',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stats row
                  Row(children: [
                    _StatPill(label: 'Best', value: '${longestStreak}d'),
                    const SizedBox(width: 10),
                    _StatPill(label: 'Study Days', value: '$totalStudyDays'),
                  ]),
                  const SizedBox(height: 16),
                  // User name
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rank share card ───────────────────────────────────────────────────────────

class RankShareCard extends StatelessWidget {
  final String displayName;
  final int rank;
  final int currentStreak;
  final int totalStudyDays;
  final int materialsOpened;
  final String mode;

  const RankShareCard({
    super.key,
    required this.displayName,
    required this.rank,
    required this.currentStreak,
    required this.totalStudyDays,
    required this.materialsOpened,
    required this.mode,
  });

  String get _modeLabel {
    switch (mode) {
      case 'weekly':  return 'THIS WEEK';
      case 'monthly': return 'THIS MONTH';
      default:        return 'ALL TIME';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      height: 360,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -50, right: -50,
              child: _Circle(size: 200, color: Colors.white.withOpacity(0.05)),
            ),
            Positioned(
              bottom: -20, left: -20,
              child: _Circle(size: 120, color: Colors.amber.withOpacity(0.1)),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BrandingRow(),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '#$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 76,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('RANKED',
                                style: TextStyle(color: Colors.white60,
                                    fontSize: 11, letterSpacing: 2)),
                            Text(_modeLabel,
                                style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'STUDY CHAMPIONS 🏆',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    _StatPill(label: 'Streak', value: '${currentStreak}🔥', dark: true),
                    const SizedBox(width: 8),
                    _StatPill(label: 'Days', value: '$totalStudyDays', dark: true),
                    const SizedBox(width: 8),
                    _StatPill(label: 'Materials', value: '$materialsOpened', dark: true),
                  ]),
                  const SizedBox(height: 16),
                  Text(displayName,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Achievement share card ────────────────────────────────────────────────────

class AchievementShareCard extends StatelessWidget {
  final String displayName;
  final String achievementIcon;
  final String achievementTitle;
  final String achievementDescription;
  final String badgeType;

  const AchievementShareCard({
    super.key,
    required this.displayName,
    required this.achievementIcon,
    required this.achievementTitle,
    required this.achievementDescription,
    required this.badgeType,
  });

  Color get _badgeColor {
    switch (badgeType) {
      case 'gold':     return const Color(0xFFFFD700);
      case 'silver':   return const Color(0xFFC0C0C0);
      case 'platinum': return const Color(0xFFB8B8FF);
      default:         return const Color(0xFFCD7F32);
    }
  }

  List<Color> get _gradientColors {
    switch (badgeType) {
      case 'gold':     return [const Color(0xFF7B4F00), const Color(0xFFB8860B)];
      case 'silver':   return [const Color(0xFF4A4A4A), const Color(0xFF767676)];
      case 'platinum': return [const Color(0xFF2D2060), const Color(0xFF5248A0)];
      default:         return [const Color(0xFF4E2800), const Color(0xFF7B4A1A)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      height: 360,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -40, right: -40,
              child: _Circle(size: 180, color: _badgeColor.withOpacity(0.08)),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BrandingRow(),
                  const SizedBox(height: 8),
                  // "Achievement Unlocked" header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _badgeColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _badgeColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      '🏅  ACHIEVEMENT UNLOCKED',
                      style: TextStyle(
                        color: _badgeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Big icon
                  Text(achievementIcon,
                      style: const TextStyle(fontSize: 64)),
                  const SizedBox(height: 10),
                  Text(
                    achievementTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    achievementDescription,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(displayName,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Milestone share card ──────────────────────────────────────────────────────

class MilestoneShareCard extends StatelessWidget {
  final String displayName;
  final int totalStudyDays;
  final int materialsOpened;
  final int achievementsUnlocked;
  final int longestStreak;

  const MilestoneShareCard({
    super.key,
    required this.displayName,
    required this.totalStudyDays,
    required this.materialsOpened,
    required this.achievementsUnlocked,
    required this.longestStreak,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      height: 360,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF004D40), Color(0xFF00695C), Color(0xFF00796B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -50, right: -50,
              child: _Circle(size: 220, color: Colors.white.withOpacity(0.05)),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BrandingRow(),
                  const SizedBox(height: 4),
                  const Text(
                    'MY PROGRESS 📊',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  // 2×2 stat grid
                  Row(children: [
                    _MilestoneStat(
                      value: '$totalStudyDays',
                      label: 'Study Days',
                      icon: '📅',
                    ),
                    const SizedBox(width: 10),
                    _MilestoneStat(
                      value: '$materialsOpened',
                      label: 'Materials',
                      icon: '📚',
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _MilestoneStat(
                      value: '$longestStreak',
                      label: 'Best Streak',
                      icon: '🔥',
                    ),
                    const SizedBox(width: 10),
                    _MilestoneStat(
                      value: '$achievementsUnlocked',
                      label: 'Achievements',
                      icon: '🏅',
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(displayName,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _BrandingRow extends StatelessWidget {
  const _BrandingRow();
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Center(
        child: Text('CS', style: TextStyle(
            color: Colors.white, fontSize: 11,
            fontWeight: FontWeight.w900)),
      ),
    ),
    const SizedBox(width: 8),
    const Text('CS Simplified',
        style: TextStyle(color: Colors.white70, fontSize: 12,
            fontWeight: FontWeight.w600)),
  ]);
}

class _Circle extends StatelessWidget {
  final double size;
  final Color color;
  const _Circle({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class _StatPill extends StatelessWidget {
  final String label, value;
  final bool dark;
  const _StatPill({required this.label, required this.value,
      this.dark = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: dark
          ? Colors.white.withOpacity(0.1)
          : Colors.black.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      Text(label, style: const TextStyle(
          color: Colors.white60, fontSize: 9)),
    ]),
  );
}

class _MilestoneStat extends StatelessWidget {
  final String value, label, icon;
  const _MilestoneStat(
      {required this.value, required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(
              color: Colors.white, fontSize: 20,
              fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(
              color: Colors.white60, fontSize: 10)),
        ],
      ),
    ),
  );
}
