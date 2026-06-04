import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/notification_provider.dart';
import '../auth/login_screen.dart';
import '../notifications/notifications_screen.dart';
import '../contact/contact_screen.dart';
import '../feedback/feedback_screen.dart';
import '../request/request_material_screen.dart';
import '../leaderboard/study_champions_screen.dart';
import '../achievements/achievements_screen.dart';
import '../sharing/share_progress_screen.dart';
import '../faq/faq_screen.dart';
import '../../core/api_client.dart';
import '../../core/storage.dart';

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

              // ── Delete Account (students only) ───────────────────────────────
              if (auth.isLoggedIn && !auth.isAdmin) ...[
                const SizedBox(height: 8),
                const _DeleteAccountTile(),
              ],

              const SizedBox(height: 16),
              _SectionHeader(title: 'Progress'),
              _MenuItem(
                icon: Icons.emoji_events_rounded,
                title: 'Study Champions',
                subtitle: 'View leaderboard and your rank',
                color: Colors.amber,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const StudyChampionsScreen())),
              ),
              _MenuItem(
                icon: Icons.military_tech_rounded,
                title: 'Achievements',
                subtitle: 'View your badges and milestones',
                color: Colors.purple,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AchievementsScreen())),
              ),
              _MenuItem(
                icon: Icons.share_rounded,
                title: 'Share Progress',
                subtitle: 'Share your streak, rank or achievements',
                color: Colors.teal,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const ShareProgressScreen())),
              ),
              const SizedBox(height: 16),
              _SectionHeader(title: 'Support'),
              const SizedBox(height: 10),
              _MenuItem(
                icon: Icons.quiz_outlined,
                title: 'FAQ',
                subtitle: 'Find quick answers to common questions',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FaqScreen())),
              ),
              const SizedBox(height: 8),
              _MenuItem(
                icon: Icons.add_comment_outlined,
                title: 'Request a Material',
                subtitle: 'Ask for a specific past question or note',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const RequestMaterialScreen())),
              ),
              const SizedBox(height: 8),
              _MenuItem(
                icon: Icons.contact_support_outlined,
                title: 'Contact Admin',
                subtitle: 'Report issues or ask questions',
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


// ── Delete Account tile ───────────────────────────────────────────────────────
// A StatefulWidget so it can hold the TextEditingController and loading state.

class _DeleteAccountTile extends StatefulWidget {
  const _DeleteAccountTile();
  @override State<_DeleteAccountTile> createState() => _DeleteAccountTileState();
}

class _DeleteAccountTileState extends State<_DeleteAccountTile> {
  bool _deleting = false;

  Future<void> _handleDelete() async {
    // ── Step 1: Warning dialog ─────────────────────────────────────────────
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_rounded, color: Colors.red, size: 22),
          SizedBox(width: 8),
          Text('Delete Account'),
        ]),
        content: const Text(
          'Deleting your account is permanent.\n\n'
          'You will lose:\n'
          '• Profile data\n'
          '• Bookmarks\n'
          '• Download history\n'
          '• Support tickets\n'
          '• Achievements (future)\n\n'
          'This action cannot be undone.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    // ── Step 2: Type DELETE confirmation ──────────────────────────────────
    final confirmCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Final Confirmation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Type DELETE to confirm:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                onChanged: (_) => setS(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: confirmCtrl.text.trim() == 'DELETE'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: Text('Delete My Account',
                  style: TextStyle(
                      color: confirmCtrl.text.trim() == 'DELETE'
                          ? Colors.red
                          : Colors.grey,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    confirmCtrl.dispose();
    if (confirmed != true || !mounted) return;

    // ── Step 3: Call API ──────────────────────────────────────────────────
    setState(() => _deleting = true);
    try {
      await ApiClient.deleteAccount();
      if (!mounted) return;
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Account deleted successfully.'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.message}'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Unexpected error: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: _deleting
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.red),
                )
              : const Icon(Icons.delete_forever_rounded,
                  color: Colors.red, size: 20),
        ),
        title: const Text('Delete Account',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
        subtitle: Text('Permanently remove your account',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        trailing: Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: Colors.red.withOpacity(0.5)),
        onTap: _deleting ? null : _handleDelete,
      ),
    );
  }
}
