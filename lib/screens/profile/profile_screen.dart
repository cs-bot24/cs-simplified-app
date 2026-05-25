import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/notification_provider.dart';
import '../auth/login_screen.dart';
import '../notifications/notifications_screen.dart';
import '../contact/contact_screen.dart';
import '../feedback/feedback_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final theme  = context.watch<ThemeProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        child: Column(children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
            color: scheme.primary,
            child: Column(children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 12),
              Text(
                auth.isLoggedIn ? auth.user!.fullName : 'Guest',
                style: const TextStyle(color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              if (auth.isLoggedIn) ...[
                const SizedBox(height: 4),
                Text(auth.user!.email,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: auth.isAdmin
                        ? Colors.orange.withOpacity(0.3)
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    auth.isAdmin ? '🔧 Admin' : '🎓 Student',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [

              // Theme section
              _SectionHeader(title: 'Appearance'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Theme', style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 14),
                      Row(children: [
                        _ThemeOption(
                          emoji: '☀️', label: 'Light',
                          selected: theme.mode == ThemeMode.light,
                          onTap: () => theme.setTheme(ThemeMode.light),
                        ),
                        const SizedBox(width: 10),
                        _ThemeOption(
                          emoji: '🌙', label: 'Dark',
                          selected: theme.mode == ThemeMode.dark,
                          onTap: () => theme.setTheme(ThemeMode.dark),
                        ),
                        const SizedBox(width: 10),
                        _ThemeOption(
                          emoji: '📱', label: 'System',
                          selected: theme.mode == ThemeMode.system,
                          onTap: () => theme.setTheme(ThemeMode.system),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              _SectionHeader(title: 'Account'),
              const SizedBox(height: 10),

              // Notifications (with unread badge)
              Consumer<NotificationProvider>(
                builder: (_, notifs, __) => _MenuItem(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: notifs.unreadCount > 0
                      ? '${notifs.unreadCount} unread'
                      : 'Stay up to date',
                  badge: notifs.unreadCount > 0 ? notifs.unreadCount : null,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                ),
              ),
              const SizedBox(height: 8),

              if (!auth.isLoggedIn)
                _MenuItem(
                  icon: Icons.login_rounded, title: 'Sign In',
                  subtitle: 'Access your saved materials',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LoginScreen())),
                )
              else
                _MenuItem(
                  icon: Icons.logout_rounded, title: 'Sign Out',
                  subtitle: 'Log out of your account',
                  color: Colors.red,
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Sign Out'),
                        content: const Text('Are you sure you want to sign out?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true),
                              child: const Text('Sign Out',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (ok == true && context.mounted)
                      await context.read<AuthProvider>().logout();
                  },
                ),

              const SizedBox(height: 16),
              _SectionHeader(title: 'Support'),
              const SizedBox(height: 10),
              _MenuItem(
                icon: Icons.contact_support_outlined,
                title: 'Contact Admin',
                subtitle: 'Report issues, request materials',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ContactScreen())),
              ),
              const SizedBox(height: 8),
              _MenuItem(
                icon: Icons.rate_review_outlined,
                title: 'Give Feedback',
                subtitle: 'Rate the app, suggest features',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FeedbackScreen())),
              ),

              const SizedBox(height: 16),
              _SectionHeader(title: 'About'),
              const SizedBox(height: 10),

              _MenuItem(
                icon: Icons.info_outline_rounded,
                title: 'About CS Simplified',
                subtitle: 'Academic learning platform v1.0.0',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'CS Simplified',
                  applicationVersion: '1.0.0',
                  applicationLegalese: 'Your academic learning hub for CS students.',
                ),
              ),
              const SizedBox(height: 10),
              _MenuItem(
                icon: Icons.help_outline_rounded,
                title: 'How to Use',
                subtitle: 'Browse → Course → Download PDF',
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('How to Use'),
                    content: const Text(
                      '1. Select your level (200L, 300L, 400L)\n'
                      '2. Choose a semester\n'
                      '3. Select a course\n'
                      '4. Filter by category\n'
                      '5. Tap a material to open the PDF\n'
                      '6. Bookmark your favourite materials',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context),
                          child: const Text('Got it')),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
              Text('CS Simplified v1.0.0',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              const SizedBox(height: 24),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(title, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: Colors.grey[500], letterSpacing: 0.5)),
  );
}

class _ThemeOption extends StatelessWidget {
  final String emoji, label;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeOption({required this.emoji, required this.label,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: selected ? Colors.white : null)),
          ]),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final Color? color;
  final int? badge;
  const _MenuItem({required this.icon, required this.title,
      required this.subtitle, required this.onTap, this.color, this.badge});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: c.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: c, size: 20),
        ),
        title: Text(title, style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color)),
        subtitle: Text(subtitle, style: TextStyle(
            fontSize: 12, color: Colors.grey[500])),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$badge',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          if (badge != null) const SizedBox(width: 6),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
        ]),
        onTap: onTap,
      ),
    );
  }
}
