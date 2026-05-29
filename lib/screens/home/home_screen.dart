import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/academic_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/home_provider.dart';
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
import '../search/search_screen.dart';
import '../notifications/notifications_screen.dart';
import '../admin/admin_dashboard.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../profile/profile_screen.dart';

// ── Shell (unchanged from original — only _HomeTab is redesigned) ─────────────

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
  final _profileTab  = const ProfileScreen();
  final _adminTab    = const AdminDashboard();

  List<Widget> _screens(bool isAdmin) => isAdmin
      ? [_homeTab, _searchTab, _bookmarkTab, _adminTab, _profileTab]
      : [_homeTab, _searchTab, _bookmarkTab, _profileTab];

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final screens = _screens(isAdmin);

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
        onDestinationSelected: (i) => setState(() => _index = i),
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
          if (isAdmin)
            const NavigationDestination(
                icon: Icon(Icons.admin_panel_settings_outlined),
                selectedIcon: Icon(Icons.admin_panel_settings_rounded),
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

// ── Home tab — Phase 1.5A redesign ────────────────────────────────────────────

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
      // Streak ping is fire-and-forget — never awaited, never blocks UI
      context.read<HomeProvider>().pingStreak();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-ping streak when app returns to foreground so a new day is detected
  // even if the user left the app open overnight.
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
      MaterialPageRoute(
        builder: (_) => const ExamPrepScreen(),
      ),
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

            // ── Loading shimmer (first load, no cache) ──────────────────────
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

            // ── 3. Trending materials (horizontal scroll) ───────────────────
            if (home.data != null &&
                home.data!.trendingMaterials.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                  child: SectionHeader(
                    title: '📈 Trending This Week',
                  ),
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

            // ── 4. Continue reading (recently viewed) ───────────────────────
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

            // ── 5. Daily quote ──────────────────────────────────────────────
            if (home.data?.dailyQuote != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: QuoteCard(quote: home.data!.dailyQuote!),
                ),
              ),

            // ── 6. Browse by level ──────────────────────────────────────────
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

            // Error state (only shown when there is truly nothing to display)
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

  // ── Header builder ─────────────────────────────────────────────────────────

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
          // Row: greeting + streak badge + notification bell
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
              // Streak badge
              if (home.data != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: StreakBadge(streak: home.data!.streak),
                ),
              // Notification bell
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

          // Streak motivational message (only shown when streak > 0)
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

          // Search hint bar
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

// ── Level card (unchanged) ────────────────────────────────────────────────────

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

// ── Inline error banner ───────────────────────────────────────────────────────

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
              style:
                  const TextStyle(fontSize: 13, color: Colors.red)),
        ),
        TextButton(
          onPressed: onRetry,
          child: const Text('Retry', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}
