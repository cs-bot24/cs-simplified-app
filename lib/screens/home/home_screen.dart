// lib/screens/home/home_screen.dart
//
// Responsive shell.
//
// Mobile (<900px):  current bottom NavigationBar — unchanged.
// Desktop (≥900px): left NavigationRail replaces bottom nav.
//                   On web, the Offline tab is hidden (no filesystem).
//
// The IndexedStack and all tab screens are identical on both layouts.
// Only the navigation chrome changes.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/academic_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/offline_provider.dart';
import '../../providers/admin_stats_provider.dart';
import '../../providers/study_planner_provider.dart';
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
import '../ai/ai_tutor_screen.dart';
import '../study_planner/study_planner_screen.dart';
import '../lecturer/ai_lecturer_screen.dart';

// ── Responsive breakpoint ─────────────────────────────────────────────────────
const _kDesktopBreakpoint = 900.0;

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
  final _plannerTab  = const StudyPlannerScreen();
  final _profileTab  = const ProfileScreen();
  final _adminTab    = const AdminDashboard();

  // On web, the Offline tab is hidden — no local filesystem.
  // Tab order: Home · Search · Saved · [Offline on mobile] · Planner · [Admin] · Profile
  List<Widget> _screens(bool isAdmin) {
    final base = kIsWeb
        ? [_homeTab, _searchTab, _bookmarkTab, _plannerTab, _profileTab]
        : [_homeTab, _searchTab, _bookmarkTab, _offlineTab, _plannerTab, _profileTab];
    if (isAdmin) {
      final adminPos = kIsWeb ? 4 : 5;
      return [...base.sublist(0, adminPos), _adminTab, ...base.sublist(adminPos)];
    }
    return base;
  }

  int _adminTabIndex(bool isAdmin) {
    if (!isAdmin) return -1;
    return kIsWeb ? 4 : 5;
  }

  // Planner tab index depends on platform and admin status
  int _plannerTabIndex(bool isAdmin) {
    if (kIsWeb) return isAdmin ? 5 : 3;
    return isAdmin ? 6 : 4;
  }

  bool _statsFetched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      auth.addListener(_onAuthChanged);
      _tryFetchStats();
    });
  }

  void _onAuthChanged() => _tryFetchStats();

  void _tryFetchStats() {
    if (!mounted) return;
    final isAdmin = context.read<AuthProvider>().isAdmin;
    if (isAdmin && !_statsFetched) {
      _statsFetched = true;
      context.read<AdminStatsProvider>().fetchStats();
    }
    if (!isAdmin) _statsFetched = false;
  }

  @override
  void dispose() {
    try { context.read<AuthProvider>().removeListener(_onAuthChanged); } catch (_) {}
    super.dispose();
  }

  void _onTabSelected(int i, bool isAdmin) {
    setState(() => _index = i);
    if (i == _adminTabIndex(isAdmin)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AdminStatsProvider>().fetchStats();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth       = context.watch<AuthProvider>();
    final isAdmin    = auth.isAdmin;
    final screens    = _screens(isAdmin);
    final adminStats = context.watch<AdminStatsProvider>();
    final totalUnread = isAdmin
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

    final plannerBadge = context.watch<StudyPlannerProvider>().unfinishedCount;

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop   = screenWidth >= _kDesktopBreakpoint;

    if (isDesktop) {
      return _DesktopShell(
        index:        safeIndex,
        screens:      screens,
        isAdmin:      isAdmin,
        totalUnread:  totalUnread,
        onSelect:     (i) => _onTabSelected(i, isAdmin),
        plannerIndex: _plannerTabIndex(isAdmin),
        plannerBadge: plannerBadge,
      );
    }

    // ── Mobile layout — unchanged ────────────────────────────────────────────
    return Scaffold(
      body: IndexedStack(index: safeIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => _onTabSelected(i, isAdmin),
        destinations: _buildDestinations(isAdmin, totalUnread, plannerBadge),
      ),
    );
  }

  List<NavigationDestination> _buildDestinations(
      bool isAdmin, int totalUnread, int plannerBadge) {
    return [
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
      if (!kIsWeb)
        const NavigationDestination(
            icon: Icon(Icons.download_for_offline_outlined),
            selectedIcon: Icon(Icons.download_for_offline_rounded),
            label: 'Offline'),
      NavigationDestination(
          icon: _PlannerNavIcon(
              icon: Icons.calendar_today_outlined, badge: plannerBadge),
          selectedIcon: _PlannerNavIcon(
              icon: Icons.calendar_today_rounded, badge: plannerBadge),
          label: 'Planner'),
      if (isAdmin)
        NavigationDestination(
            icon: _AdminNavIcon(
                icon: Icons.admin_panel_settings_outlined,
                badge: totalUnread, selected: false),
            selectedIcon: _AdminNavIcon(
                icon: Icons.admin_panel_settings_rounded,
                badge: totalUnread, selected: true),
            label: 'Admin'),
      const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile'),
    ];
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// Desktop Shell — NavigationRail + content
// ══════════════════════════════════════════════════════════════════════════════

class _DesktopShell extends StatelessWidget {
  final int           index;
  final List<Widget>  screens;
  final bool          isAdmin;
  final int           totalUnread;
  final void Function(int) onSelect;
  final int           plannerIndex;
  final int           plannerBadge;

  const _DesktopShell({
    required this.index,
    required this.screens,
    required this.isAdmin,
    required this.totalUnread,
    required this.onSelect,
    required this.plannerIndex,
    required this.plannerBadge,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          // ── Left navigation rail ────────────────────────────────────────
          NavigationRail(
            selectedIndex:    index,
            onDestinationSelected: onSelect,
            labelType:        NavigationRailLabelType.all,
            backgroundColor: isDark
                ? const Color(0xFF1E1E1E)
                : const Color(0xFFF8F8F8),
            indicatorColor:  scheme.primary.withOpacity(0.15),
            selectedIconTheme: IconThemeData(color: scheme.primary),
            selectedLabelTextStyle: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 11,
            ),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('CS',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ]),
            ),
            destinations: _buildRailDestinations(context),
          ),

          // Vertical divider
          VerticalDivider(
            width: 1,
            color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
          ),

          // ── Main content ────────────────────────────────────────────────
          Expanded(
            child: IndexedStack(index: index, children: screens),
          ),
        ],
      ),
    );
  }

  List<NavigationRailDestination> _buildRailDestinations(BuildContext context) {
    final dests = <NavigationRailDestination>[
      const NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: Text('Home')),
      const NavigationRailDestination(
          icon: Icon(Icons.search_outlined),
          selectedIcon: Icon(Icons.search_rounded),
          label: Text('Search')),
      const NavigationRailDestination(
          icon: Icon(Icons.bookmark_outline),
          selectedIcon: Icon(Icons.bookmark_rounded),
          label: Text('Saved')),
      NavigationRailDestination(
          icon: _PlannerNavIcon(
              icon: Icons.calendar_today_outlined, badge: plannerBadge),
          selectedIcon: _PlannerNavIcon(
              icon: Icons.calendar_today_rounded, badge: plannerBadge),
          label: const Text('Planner')),
    ];

    if (isAdmin) {
      dests.add(NavigationRailDestination(
          icon: _AdminNavIcon(
              icon: Icons.admin_panel_settings_outlined,
              badge: totalUnread, selected: false),
          selectedIcon: _AdminNavIcon(
              icon: Icons.admin_panel_settings_rounded,
              badge: totalUnread, selected: true),
          label: const Text('Admin')));
    }

    dests.add(const NavigationRailDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person_rounded),
        label: Text('Profile')));

    return dests;
  }
}


// ── Planner nav icon with unfinished-sessions badge ───────────────────────────

class _PlannerNavIcon extends StatelessWidget {
  final IconData icon;
  final int      badge;
  const _PlannerNavIcon({required this.icon, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (badge > 0)
          Positioned(
            top: -4, right: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                style: const TextStyle(
                    color: Colors.white, fontSize: 9,
                    fontWeight: FontWeight.bold, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}


// ── Admin nav icon with badge ─────────────────────────────────────────────────

class _AdminNavIcon extends StatelessWidget {
  final IconData icon;
  final int      badge;
  final bool     selected;
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
            top: -4, right: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                style: const TextStyle(
                    color: Colors.white, fontSize: 9,
                    fontWeight: FontWeight.bold, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// Home Tab (content — identical on mobile and desktop)
// ══════════════════════════════════════════════════════════════════════════════

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
      context.read<StudyPlannerProvider>().refresh();
      if (!kIsWeb) context.read<OfflineProvider>().loadFromStorage();
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
      context.read<StudyPlannerProvider>().refreshIfNewDay();
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      context.read<HomeProvider>().fetchHome(forceRefresh: true),
      context.read<AcademicProvider>().fetchLevels(forceRefresh: true),
    ]);
  }

  void _goToExamPrep() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const ExamPrepScreen()));

  int _plannerIndex(BuildContext context) {
    final isAdmin = context.read<AuthProvider>().isAdmin;
    return kIsWeb ? (isAdmin ? 5 : 3) : (isAdmin ? 6 : 4);
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final academic = context.watch<AcademicProvider>();
    final home     = context.watch<HomeProvider>();
    final scheme   = Theme.of(context).colorScheme;
    final name     = auth.user?.fullName.split(' ').first ?? 'Student';
    final isDesktop = MediaQuery.of(context).size.width >= _kDesktopBreakpoint;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          slivers: [

            // ── 1. Hero header ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildHeader(context, scheme, name, home, isDesktop),
            ),

            if (home.loading && home.data == null)
              const SliverToBoxAdapter(child: HomeShimmer()),

            // ── 2. Exam prep banner ─────────────────────────────────────────
            if (home.data != null && home.data!.examPrepCount > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: ExamPrepBanner(
                      count: home.data!.examPrepCount, onTap: _goToExamPrep),
                ),
              ),

            // ── 2b. Study Reminders card ─────────────────────────────────────
            const SliverToBoxAdapter(child: _StudyRemindersCard()),

            // ── 2c. Daily quote ──────────────────────────────────────────────
            // Placed right after the occasional Exam Prep / Study Plan
            // banners but before Study Champions, so it's always visible on
            // launch (those two banners only render occasionally, so this
            // used to require scrolling past Trending + Continue Reading to
            // find it most of the time).
            if (home.data?.dailyQuote != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: QuoteCard(quote: home.data!.dailyQuote!),
                ),
              ),

            // ── 3. Leaderboard entry card ────────────────────────────────────
            if (home.data != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _LeaderboardEntryCard(
                    streak: home.data!.streak.currentStreak,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const StudyChampionsScreen())),
                  ),
                ),
              ),

            // ── 4. Trending materials ───────────────────────────────────────
            if (home.data != null &&
                home.data!.trendingMaterials.isNotEmpty) ...  [
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
                        material: home.data!.trendingMaterials[i]),
                  ),
                ),
              ),
            ],

            // ── 5. Continue reading ─────────────────────────────────────────
            if (home.data != null &&
                home.data!.recentlyViewed.isNotEmpty) ...[
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
                        material: home.data!.recentlyViewed[i]),
                    childCount: home.data!.recentlyViewed.length,
                  ),
                ),
              ),
            ],

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
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const RequestMaterialScreen())),
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
                    // Hide "Downloaded" quick action on web
                    if (!kIsWeb) ...[
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.school_rounded,
                        label: 'AI Lecturer',
                        color: const Color(0xFF1A3C6E),
                        wide: false,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AiLecturerScreen()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // AI Tutor card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _QuickActionCard(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI Tutor',
                  color: const Color(0xFF1A3C6E),
                  wide: true,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const AiTutorScreen())),
                ),
              ),
            ),

            // Study Planner card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _QuickActionCard(
                  icon: Icons.calendar_today_rounded,
                  label: 'Study Planner',
                  color: const Color(0xFF6C63FF),
                  wide: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const StudyPlannerScreen()),
                  ),
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
                        onTap: () => Navigator.push(ctx,
                            MaterialPageRoute(
                                builder: (_) =>
                                    LevelsScreen(level: level))),
                      );
                    },
                    childCount: academic.levels.length,
                  ),
                ),
              ),

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

  Widget _buildHeader(BuildContext context, ColorScheme scheme,
      String name, HomeProvider home, bool isDesktop) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, isDesktop ? 32 : 56, 24, 28),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
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
                    Text('Hello, $name 👋',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 2),
                    const Text('CS Simplified',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
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
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen())),
                  child: Stack(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.notifications_outlined,
                            color: Colors.white, size: 20),
                      ),
                      if (notifs.unreadCount > 0)
                        Positioned(
                          top: 6, right: 6,
                          child: Container(
                            width: 9, height: 9,
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle),
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
            Text(home.data!.streak.motivationalMessage,
                style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
          ],

          const SizedBox(height: 16),
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
              Text('Browse materials by level',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),
        ],
      ),
    );
  }
}


// ── Level card ────────────────────────────────────────────────────────────────

class _LevelCard extends StatelessWidget {
  final LevelModel   level;
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
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
                child: Text(level.emoji,
                    style: const TextStyle(fontSize: 26))),
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
  final String       message;
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
        Expanded(child: Text(message,
            style: const TextStyle(fontSize: 13, color: Colors.red))),
        TextButton(
            onPressed: onRetry,
            child: const Text('Retry', style: TextStyle(fontSize: 12))),
      ]),
    );
  }
}


// ── Quick action card ─────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  final bool         wide;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: wide
              ? const EdgeInsets.symmetric(vertical: 14, horizontal: 20)
              : const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: wide
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 24),
                    const SizedBox(width: 10),
                    Text(label,
                        style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w600, color: color)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('PRO',
                          style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.bold, color: color)),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 26),
                    const SizedBox(height: 8),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color, height: 1.3)),
                  ],
                ),
        ),
      ),
    );
  }
}


// ── Leaderboard entry card ────────────────────────────────────────────────────

class _LeaderboardEntryCard extends StatelessWidget {
  final int          streak;
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
          gradient: LinearGradient(colors: [
            Colors.amber.withOpacity(0.15),
            scheme.primary.withOpacity(0.08),
          ]),
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('View',
                  style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.bold, color: Colors.amber)),
            ),
            const SizedBox(width: 6),
            if (!kIsWeb)
              GestureDetector(
                onTap: () => Navigator.push(context,
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


// ══════════════════════════════════════════════════════════════════════════════
// Study Reminders Card — Home screen visibility for today's study sessions
// ══════════════════════════════════════════════════════════════════════════════

const _kPlannerAccent = Color(0xFF6C63FF);

class _StudyRemindersCard extends StatelessWidget {
  const _StudyRemindersCard();

  void _openSheet(BuildContext context, List<TodayStudySession> sessions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TodaySessionsSheet(sessions: sessions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final planner     = context.watch<StudyPlannerProvider>();
    final unfinished  = planner.unfinishedToday;

    // Conditions: only render when there's at least one unfinished
    // session scheduled today. Otherwise, render nothing at all.
    if (unfinished.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count  = unfinished.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openSheet(context, unfinished),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kPlannerAccent.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _kPlannerAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('📚', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Study Reminders',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: scheme.onSurface)),
                      const SizedBox(height: 2),
                      Text(
                        'You have $count study session${count == 1 ? '' : 's'} scheduled today.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("View Today's Sessions",
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: _kPlannerAccent)),
                          const SizedBox(width: 2),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 16, color: _kPlannerAccent),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// Today's Sessions — bottom sheet
// ══════════════════════════════════════════════════════════════════════════════

class _TodaySessionsSheet extends StatelessWidget {
  final List<TodayStudySession> sessions;
  const _TodaySessionsSheet({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text("📚 Today's Study Sessions",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface)),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _TodaySessionTile(session: sessions[i]),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const StudyPlannerScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPlannerAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.calendar_today_rounded,
                    color: Colors.white, size: 16),
                label: const Text('Open Planner',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodaySessionTile extends StatelessWidget {
  final TodayStudySession session;
  const _TodaySessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeFmt = DateFormat('h:mm a');
    final timeRange =
        '${timeFmt.format(session.start)} - ${timeFmt.format(session.end)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F2FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _kPlannerAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(session.courseLabel,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kPlannerAccent)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(session.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface)),
          ),
          const SizedBox(width: 8),
          Text(timeRange,
              style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.white60 : Colors.black54)),
        ],
      ),
    );
  }
}
