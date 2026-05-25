import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/academic_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/level_model.dart';
import '../../widgets/skeleton_loader.dart';
import '../browse/levels_screen.dart';
import '../search/search_screen.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../profile/profile_screen.dart';
import '../admin/admin_dashboard.dart';
import '../notifications/notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  List<Widget> _screens(bool isAdmin) => [
    const _HomeTab(),
    const SearchScreen(),
    const BookmarksScreen(),
    if (isAdmin) const AdminDashboard(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final screens = _screens(isAdmin);

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
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

class _HomeTab extends StatefulWidget {
  const _HomeTab();
  @override State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademicProvider>().fetchLevels();
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final academic = context.watch<AcademicProvider>();
    final scheme   = Theme.of(context).colorScheme;
    final name     = auth.user?.fullName.split(' ').first ?? 'Student';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Hello, $name 👋',
                            style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('CS Simplified',
                            style: TextStyle(color: Colors.white, fontSize: 22,
                                fontWeight: FontWeight.bold)),
                      ]),
                      Consumer<NotificationProvider>(
                        builder: (_, notifs, __) => GestureDetector(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                          child: Stack(
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.notifications_outlined,
                                    color: Colors.white),
                              ),
                              if (notifs.unreadCount > 0)
                                Positioned(
                                  top: 6, right: 6,
                                  child: Container(
                                    width: 10, height: 10,
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
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(children: [
                      Icon(Icons.lightbulb_outline, color: Colors.white70, size: 18),
                      SizedBox(width: 10),
                      Text('Browse materials by level',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 28, 24, 16),
              child: Text('Select Your Level',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          if (academic.loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SkeletonList(count: 4),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final level = academic.levels[i];
                    return _LevelCard(level: level,
                      onTap: () => Navigator.push(ctx,
                          MaterialPageRoute(builder: (_) => LevelsScreen(level: level))),
                    );
                  },
                  childCount: academic.levels.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

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
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(level.emoji,
                style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(level.levelName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('Tap to browse courses',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          )),
          Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
        ]),
      ),
    );
  }
}
