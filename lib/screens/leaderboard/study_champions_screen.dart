import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/leaderboard_provider.dart';
import '../../models/leaderboard_model.dart';

class StudyChampionsScreen extends StatefulWidget {
  const StudyChampionsScreen({super.key});
  @override State<StudyChampionsScreen> createState() => _StudyChampionsScreenState();
}

class _StudyChampionsScreenState extends State<StudyChampionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  static const _modes  = ['all_time', 'weekly', 'monthly'];
  static const _labels = ['All Time', 'This Week', 'This Month'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        context.read<LeaderboardProvider>()
            .switchMode(_modes[_tabs.index]);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaderboardProvider>().fetchLeaderboard();
    });
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lb     = context.watch<LeaderboardProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Champions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => lb.fetchLeaderboard(mode: lb.mode),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: _labels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: lb.loading
          ? const Center(child: CircularProgressIndicator())
          : lb.error != null
              ? _ErrorView(error: lb.error!, onRetry: () => lb.fetchLeaderboard(mode: lb.mode))
              : lb.data == null
                  ? const SizedBox()
                  : TabBarView(
                      controller: _tabs,
                      physics: const NeverScrollableScrollPhysics(),
                      children: List.generate(3, (_) =>
                          _LeaderboardBody(data: lb.data!, scheme: scheme)),
                    ),
    );
  }
}

// ── Main body ─────────────────────────────────────────────────────────────────

class _LeaderboardBody extends StatelessWidget {
  final LeaderboardData data;
  final ColorScheme scheme;
  const _LeaderboardBody({required this.data, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final top3  = data.topUsers.take(3).toList();
    final rest  = data.topUsers.skip(3).toList();
    final me    = data.myStats;
    final inTop = data.topUsers.any((e) => e.isCurrentUser);

    return RefreshIndicator(
      onRefresh: () => context.read<LeaderboardProvider>()
          .fetchLeaderboard(mode: data.mode),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── My Rank Card ───────────────────────────────────────────────
          _MyRankCard(stats: me, scheme: scheme),
          const SizedBox(height: 20),

          // ── Top 3 Podium ───────────────────────────────────────────────
          if (top3.isNotEmpty) ...[
            const _SectionLabel(text: '🏆 Top Learners'),
            const SizedBox(height: 12),
            _PodiumRow(top3: top3, scheme: scheme),
            const SizedBox(height: 20),
          ],

          // ── Ranks 4–20 ─────────────────────────────────────────────────
          if (rest.isNotEmpty) ...[
            const _SectionLabel(text: 'Rankings'),
            const SizedBox(height: 10),
            ...rest.map((e) => _RankTile(entry: e)),
          ],

          // If current user is not in top 20, show them at bottom
          if (!inTop && me.rank > 0) ...[
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 4),
            _RankTile(
              entry: LeaderboardEntry(
                rank: me.rank,
                userId: 0,
                displayName: 'You',
                currentStreak: me.currentStreak,
                longestStreak: me.longestStreak,
                totalStudyDays: me.totalStudyDays,
                materialsOpened: me.materialsOpened,
                score: me.score,
                isCurrentUser: true,
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── My Rank Card ──────────────────────────────────────────────────────────────

class _MyRankCard extends StatelessWidget {
  final MyLeaderboardStats stats;
  final ColorScheme scheme;
  const _MyRankCard({required this.stats, required this.scheme});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [scheme.primary, scheme.primary.withOpacity(0.7)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(color: scheme.primary.withOpacity(0.3),
            blurRadius: 12, offset: const Offset(0, 4)),
      ],
    ),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Your Rank', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 2),
        Text('#${stats.rank}',
            style: const TextStyle(color: Colors.white, fontSize: 36,
                fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(width: 24),
      Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatChip(icon: '🔥', value: '${stats.currentStreak}d', label: 'Streak'),
            _StatChip(icon: '📅', value: '${stats.totalStudyDays}', label: 'Study Days'),
            _StatChip(icon: '📚', value: '${stats.materialsOpened}', label: 'Materials'),
          ],
        ),
      ),
    ]),
  );
}

class _StatChip extends StatelessWidget {
  final String icon, value, label;
  const _StatChip({required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(icon, style: const TextStyle(fontSize: 18)),
      Text(value, style: const TextStyle(color: Colors.white,
          fontWeight: FontWeight.bold, fontSize: 15)),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
    ],
  );
}

// ── Podium ────────────────────────────────────────────────────────────────────

class _PodiumRow extends StatelessWidget {
  final List<LeaderboardEntry> top3;
  final ColorScheme scheme;
  const _PodiumRow({required this.top3, required this.scheme});

  @override
  Widget build(BuildContext context) {
    // Order: 2nd | 1st | 3rd
    final order = [
      if (top3.length > 1) top3[1],
      top3[0],
      if (top3.length > 2) top3[2],
    ];

    final heights  = [80.0, 110.0, 60.0];
    final medals   = ['🥈', '🥇', '🥉'];
    final colors   = [Colors.grey[400]!, Colors.amber, Colors.brown[400]!];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(order.length, (i) {
        final e = order[i];
        final isFirst = e.rank == 1;
        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFirst) ...[
                const Text('👑', style: TextStyle(fontSize: 22)),
                const SizedBox(height: 4),
              ],
              CircleAvatar(
                radius: isFirst ? 26 : 22,
                backgroundColor: colors[i].withOpacity(0.2),
                child: Text(
                  e.displayName.isNotEmpty
                      ? e.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isFirst ? 20 : 16,
                      color: colors[i]),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                e.displayName.length > 10
                    ? '${e.displayName.substring(0, 9)}…'
                    : e.displayName,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: isFirst ? FontWeight.bold : FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              Text(medals[i], style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                height: heights[i],
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: colors[i].withOpacity(0.15),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border.all(color: colors[i].withOpacity(0.4)),
                ),
                child: Center(
                  child: Text('${e.currentStreak}🔥',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Rank tile (4–20) ──────────────────────────────────────────────────────────

class _RankTile extends StatelessWidget {
  final LeaderboardEntry entry;
  const _RankTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isMe = entry.isCurrentUser;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isMe
            ? scheme.primary.withOpacity(0.08)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? scheme.primary.withOpacity(0.4) : Colors.transparent,
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        SizedBox(
          width: 32,
          child: Text(
            '#${entry.rank}',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
                fontSize: 13),
          ),
        ),
        CircleAvatar(
          radius: 16,
          backgroundColor: scheme.primary.withOpacity(0.1),
          child: Text(
            entry.displayName.isNotEmpty
                ? entry.displayName[0].toUpperCase()
                : '?',
            style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.bold, color: scheme.primary),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isMe ? '${entry.displayName} (You)' : entry.displayName,
            style: TextStyle(
                fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                fontSize: 13),
          ),
        ),
        Row(children: [
          Text('${entry.currentStreak}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Text('🔥', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Text('${entry.totalStudyDays}d',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ]),
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.red),
      const SizedBox(height: 10),
      Text(error, textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600])),
      const SizedBox(height: 14),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ]),
  );
}
