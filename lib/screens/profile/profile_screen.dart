import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              color: const Color(AppConstants.primaryColorValue),
              child: Column(
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    auth.isLoggedIn
                        ? auth.user!.fullName
                        : 'Guest',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (auth.isLoggedIn) ...[
                    const SizedBox(height: 4),
                    Text(auth.user!.email,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: auth.isAdmin
                            ? Colors.orange.withOpacity(0.3)
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        auth.isAdmin ? '🔧 Admin' : '🎓 Student',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (!auth.isLoggedIn) ...[
                    _MenuItem(
                      icon: Icons.login_rounded,
                      title: 'Sign In',
                      subtitle: 'Access your saved materials',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen())),
                    ),
                    const SizedBox(height: 12),
                  ],

                  _MenuItem(
                    icon: Icons.info_outline_rounded,
                    title: 'About CS Simplified',
                    subtitle: 'Academic learning platform',
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'CS Simplified',
                      applicationVersion: '1.0.0',
                      applicationLegalese:
                          'Your academic learning hub for CS students.',
                    ),
                  ),
                  const SizedBox(height: 12),

                  _MenuItem(
                    icon: Icons.help_outline_rounded,
                    title: 'How to Use',
                    subtitle: 'Browse levels → semesters → courses → download',
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
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (auth.isLoggedIn) ...[
                    const SizedBox(height: 12),
                    _MenuItem(
                      icon: Icons.logout_rounded,
                      title: 'Sign Out',
                      subtitle: 'Log out of your account',
                      color: const Color(AppConstants.errorColorValue),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Sign Out'),
                            content: const Text(
                                'Are you sure you want to sign out?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('Sign Out',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          await context.read<AuthProvider>().logout();
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('CS Simplified v1.0.0',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400])),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(AppConstants.primaryColorValue);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(AppConstants.accentColorValue),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: c.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: c, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: c == const Color(AppConstants.errorColorValue)
                              ? c
                              : const Color(AppConstants.textDarkValue))),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(AppConstants.textLightValue))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
