import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/achievement_provider.dart';
import '../sharing/share_progress_screen.dart';
import '../../models/achievement_model.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});
  @override State<AchievementsScreen> createState() =>
      _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AchievementProvider>().fetchAchievements();
    });
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final prov   = context.watch<AchievementProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                context.read<AchievementProvider>().fetchAchievements(),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'All (${prov.totalCount})'),
            Tab(text: 'Unlocked (${prov.unlockedCount})'),
          ],
        ),
      ),
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : prov.error != null
              ? _ErrorView(
                  message: prov.error!,
                  onRetry: () => prov.fetchAchievements(),
                )
              : Column(
                  children: [
                    // ── Summary banner ─────────────────────────────────────
                    if (prov.totalCount > 0)
                      _SummaryBanner(
                        unlocked: prov.unlockedCount,
                        total: prov.totalCount,
                        scheme: scheme,
                      ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          // All tab
                          _AchievementGrid(
                            achievements: prov.achievements,
                            emptyMessage: 'No achievements available.',
                          ),
                          // Unlocked tab
                          _AchievementGrid(
                            achievements: prov.unlocked,
                            emptyMessage:
                                'No achievements unlocked yet.\nKeep studying!',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ── Summary banner ────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final int unlocked, total;
  final ColorScheme scheme;
  const _SummaryBanner(
      {required this.unlocked, required this.total, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? unlocked / total : 0.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withOpacity(0.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        const Text('🏅', style: TextStyle(fontSize: 32)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$unlocked / $total Unlocked',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Text(
          '${(pct * 100).toInt()}%',
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
      ]),
    );
  }
}

// ── Achievement grid ──────────────────────────────────────────────────────────

class _AchievementGrid extends StatelessWidget {
  final List<AchievementModel> achievements;
  final String emptyMessage;
  const _AchievementGrid(
      {required this.achievements, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🔒', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500],
                  height: 1.5),
            ),
          ]),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: achievements.length,
      itemBuilder: (_, i) => _AchievementCard(achievement: achievements[i]),
    );
  }
}

// ── Achievement card ──────────────────────────────────────────────────────────

class _AchievementCard extends StatelessWidget {
  final AchievementModel achievement;
  const _AchievementCard({required this.achievement});

  Color get _badgeColor {
    try {
      final hex = achievement.badgeColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final a       = achievement;
    final unlocked = a.isUnlocked;
    final color   = unlocked ? _badgeColor : Colors.grey[400]!;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: unlocked
              ? color.withOpacity(0.08)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unlocked ? color.withOpacity(0.4) : Colors.grey.withOpacity(0.2),
            width: unlocked ? 1.5 : 1,
          ),
          boxShadow: unlocked
              ? [BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + lock overlay
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(unlocked ? 0.15 : 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        unlocked ? a.icon : '🔒',
                        style: TextStyle(
                            fontSize: 24,
                            color: unlocked ? null : Colors.grey[400]),
                      ),
                    ),
                  ),
                  // Badge type pip
                  Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 1.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                a.title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: unlocked ? null : Colors.grey[500]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Description
              Expanded(
                child: Text(
                  a.description,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Progress bar (for streak/material/day conditions)
              if (!unlocked && a.progressMax != null && a.progressMax! > 0) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: a.progressFraction,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${a.progressCurrent}/${a.progressMax}',
                    style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                  ),
                ]),
              ],

              // Unlocked date
              if (unlocked && a.unlockedAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  _formatDate(a.unlockedAt!),
                  style: TextStyle(
                      fontSize: 9,
                      color: color,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final a     = achievement;
    final color = a.isUnlocked ? _badgeColor : Colors.grey;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Text(a.isUnlocked ? a.icon : '🔒',
              style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(a.title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 6),
          Text(a.description,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], height: 1.5)),
          const SizedBox(height: 16),

          // Badge type chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              a.badgeType.toUpperCase(),
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1),
            ),
          ),

          if (a.isUnlocked && a.unlockedAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Unlocked on ${_formatDateFull(a.unlockedAt!)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],

          if (!a.isUnlocked && a.progressMax != null) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: a.progressFraction,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 10,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${a.progressCurrent}/${a.progressMax}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ],
          const SizedBox(height: 8),
          // Share button (only for unlocked achievements)
          if (a.isUnlocked) ...[                                
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Share Achievement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) =>
                        const ShareProgressScreen(initialTab: 2),
                  ));
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';

  String _formatDateFull(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.red),
      const SizedBox(height: 10),
      Text(message, style: TextStyle(color: Colors.grey[600])),
      const SizedBox(height: 14),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ]),
  );
}
