import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/academic_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/offline_provider.dart';
import '../../providers/admin_stats_provider.dart';
import '../../models/level_model.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/streak_badge.dart';
import '../../widgets/material_card.dart';
import '../../widgets/quote_card.dart';
import '../../widgets/exam_prep_banner.dart';
import '../../widgets/section_header.dart';
import '../../widgets/home_shimmer.dart';
import '../browse/levels_screen.dart';
import '../exam_prep/exam_prep_screen.dart';
import '../offline/offline_screen.dart';
import '../search/search_screen.dart';
import '../notifications/notifications_screen.dart';
import '../admin/admin_dashboard.dart';
import '../request/request_material_screen.dart';
import '../leaderboard/study_champions_screen.dart';
import '../sharing/share_progress_screen.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final _homeTab     = const _HomeTab();
  final _searchTab   = const SearchScreen();
  final _bookmarkTab = const BookmarksScreen();
  final _offlineTab  = const OfflineScreen();
  final _profileTab  = const ProfileScreen();
  final _adminTab    = const AdminDashboard();

  List<Widget> _screens(bool isAdmin) => isAdmin
      ? [_homeTab, _searchTab, _bookmarkTab, _offlineTab, _adminTab, _profileTab]
      : [_homeTab, _searchTab, _bookmarkTab, _offlineTab, _profileTab];

  int _adminTabIndex(bool isAdmin) => isAdmin ? 4 : -1;

  // Track whether we have already fetched stats for this login session
  bool _statsFetched = false;

  @override
  void initState() {
    super.initState();
    // Listen to AuthProvider — the moment isAdmin becomes true (either from
    // loadFromStorage() completing or after login), fetch stats immediately.
    // Using addListener is more reliable than addPostFrameCallback because
    // it fires even if the widget is already built before isAdmin is true.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      auth.addListener(_onAuthChanged);
      // Also try immediately in case isAdmin is already true
      _tryFetchStats();
    });
  }

  void _onAuthChanged() {
    _tryFetchStats();
  }

  void _tryFetchStats() {
    if (!mounted) return;
    final isAdmin = context.read<AuthProvider>().isAdmin;
    if (isAdmin && !_statsFetched) {
      _statsFetched = true;
      context.read<AdminStatsProvider>().fetchStats();
    }
    // Reset flag on logout so next login fetches fresh
    if (!isAdmin) _statsFetched = false;
  }

  @override
  void dispose() {
    // Safe removal — addPostFrameCallback may not have fired yet if widget
    // is disposed very quickly, so guard with try/catch
    try {
      context.read<AuthProvider>().removeListener(_onAuthChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onTabSelected(int i, bool isAdmin) {
    setState(() => _index = i);
    // Re-fetch every time admin tab is tapped so badges stay live
    if (i == _adminTabIndex(isAdmin)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AdminStatsProvider>().fetchStats();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final screens = _screens(isAdmin);

    // Total unread items — drives the nav bar badge dot
    final adminStats   = context.watch<AdminStatsProvider>();
    final totalUnread  = isAdmin
        ? adminStats.pendingRequests +
          adminStats.openSupportTickets +
          adminStats.unreadFeedback
        : 0;

    final safeIndex = _index.clamp(0, screens.length - 1);
    if (safeIndex != _index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = safeIndex);
      });
    }

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => _onTabSelected(i, isAdmin),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          const NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search_rounded),
              label: 'Search'),
          const NavigationDestination(
              icon: Icon(Icons.bookmark_outline),
              selectedIcon: Icon(Icons.bookmark_rounded),
              label: 'Saved'),
          const NavigationDestination(
              icon: Icon(Icons.download_for_offline_outlined),
              selectedIcon: Icon(Icons.download_for_offline_rounded),
              label: 'Offline'),
          if (isAdmin)
            NavigationDestination(
                icon: _AdminNavIcon(
                    icon: Icons.admin_panel_settings_outlined,
                    badge: totalUnread,
                    selected: false),
                selectedIcon: _AdminNavIcon(
                    icon: Icons.admin_panel_settings_rounded,
                    badge: totalUnread,
                    selected: true),
                label: 'Admin'),
          const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile'),
        ],
      ),
    );
  }
}

// ── Admin nav icon with red dot badge ────────────────────────────────────────

class _AdminNavIcon extends StatelessWidget {
  final IconData icon;
  final int badge;
  final bool selected;
  const _AdminNavIcon({
    required this.icon,
    required this.badge,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (badge > 0)
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Home tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademicProvider>().fetchLevels();
      context.read<NotificationProvider>().fetchNotifications();
      context.read<HomeProvider>().fetchHome();
      context.read<HomeProvider>().pingStreak();
      context.read<OfflineProvider>().loadFromStorage();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<HomeProvider>().pingStreak();
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      context.read<HomeProvider>().fetchHome(forceRefresh: true),
      context.read<AcademicProvider>().fetchLevels(forceRefresh: true),
    ]);
  }

  void _goToExamPrep() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExamPrepScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final academic = context.watch<AcademicProvider>();
    final home     = context.watch<HomeProvider>();
    final scheme   = Theme.of(context).colorScheme;
    final name     = auth.user?.fullName.split(' ').first ?? 'Student';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          slivers: [

            // ── 1. Hero header ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildHeader(context, scheme, name, home),
            ),

            // ── Loading shimmer ─────────────────────────────────────────────
            if (home.loading && home.data == null)
              const SliverToBoxAdapter(child: HomeShimmer()),

            // ── 2. Exam prep banner ─────────────────────────────────────────
            if (home.data != null && home.data!.examPrepCount > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: ExamPrepBanner(
                    count: home.data!.examPrepCount,
                    onTap: _goToExamPrep,
                  ),
                ),
              ),

            // ── 3. Leaderboard entry card ───────────────────────────────────
            if (home.data != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _LeaderboardEntryCard(
                    streak: home.data!.streak.currentStreak,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const StudyChampionsScreen())),
                  ),
                ),
              ),

            // ── 4. Trending materials ───────────────────────────────────────
            if (home.data != null &&
                home.data!.trendingMaterials.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                  child: SectionHeader(title: '📈 Trending This Week'),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 150,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: home.data!.trendingMaterials.length,
                    itemBuilder: (_, i) => MaterialCard.horizontal(
                      material: home.data!.trendingMaterials[i],
                    ),
                  ),
                ),
              ),
            ],

            // ── 5. Continue reading ─────────────────────────────────────────
            if (home.data != null && home.data!.recentlyViewed.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                  child: SectionHeader(title: '⏱ Continue Reading'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => MaterialCard.vertical(
                      material: home.data!.recentlyViewed[i],
                    ),
                    childCount: home.data!.recentlyViewed.length,
                  ),
                ),
              ),
            ],

            // ── 6. Daily quote ──────────────────────────────────────────────
            if (home.data?.dailyQuote != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: QuoteCard(quote: home.data!.dailyQuote!),
                ),
              ),

            // ── 7. Quick Actions ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: SectionHeader(title: 'Quick Actions'),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.add_comment_outlined,
                        label: 'Request\nMaterial',
                        color: Colors.teal,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RequestMaterialScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.bookmark_outline_rounded,
                        label: 'My\nBookmarks',
                        color: Colors.indigo,
                        onTap: () {
                          final shell = context
                              .findAncestorStateOfType<_HomeScreenState>();
                          shell?.setState(() => shell._index = 2);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.download_done_rounded,
                        label: 'Downloaded',
                        color: Colors.green,
                        onTap: () {
                          final shell = context
                              .findAncestorStateOfType<_HomeScreenState>();
                          shell?.setState(() => shell._index = 3);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── 8. Browse by level ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                child: SectionHeader(title: 'Browse by Level'),
              ),
            ),

            if (academic.loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: SkeletonList(count: 3),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final level = academic.levels[i];
                      return _LevelCard(
                        level: level,
                        onTap: () => Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => LevelsScreen(level: level),
                          ),
                        ),
                      );
                    },
                    childCount: academic.levels.length,
                  ),
                ),
              ),

            // Error state
            if (home.error != null && home.data == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _ErrorBanner(
                    message: home.error!,
                    onRetry: () =>
                        context.read<HomeProvider>().fetchHome(forceRefresh: true),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme scheme,
    String name,
    HomeProvider home,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $name 👋',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'CS Simplified',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (home.data != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: StreakBadge(streak: home.data!.streak),
                ),
              Consumer<NotificationProvider>(
                builder: (_, notifs, __) => GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      if (notifs.unreadCount > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (home.data != null && home.data!.streak.currentStreak > 0) ...[
            const SizedBox(height: 10),
            Text(
              home.data!.streak.motivationalMessage,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(children: [
              Icon(Icons.lightbulb_outline, color: Colors.white70, size: 17),
              SizedBox(width: 10),
              Text(
                'Browse materials by level',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Level card ────────────────────────────────────────────────────────────────

class _LevelCard extends StatelessWidget {
  final LevelModel level;
  final VoidCallback onTap;
  const _LevelCard({required this.level, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.primary.withOpacity(0.1)),
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(level.emoji,
                  style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(level.levelName,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Tap to browse courses',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 16, color: Colors.grey[400]),
        ]),
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(fontSize: 13, color: Colors.red)),
        ),
        TextButton(
          onPressed: onRetry,
          child: const Text('Retry', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}

// ── Quick action card ─────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Leaderboard entry card ────────────────────────────────────────────────────

class _LeaderboardEntryCard extends StatelessWidget {
  final int streak;
  final VoidCallback onTap;
  const _LeaderboardEntryCard({required this.streak, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.withOpacity(0.15),
              scheme.primary.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Text('🏆', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Study Champions',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  streak > 0
                      ? 'Your streak: $streak day${streak == 1 ? '' : 's'} 🔥'
                      : 'Start studying to join the leaderboard',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('View',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                      color: Colors.amber)),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ShareProgressScreen())),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.share_rounded,
                    size: 14, color: Colors.amber),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
