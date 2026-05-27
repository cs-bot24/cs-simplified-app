import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/academic_provider.dart';
import '../../providers/auth_provider.dart';
import 'manage_levels_screen.dart';
import 'manage_materials_screen.dart';
import 'upload_material_screen.dart';
import 'send_notification_screen.dart';
import 'admin_feedback_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademicProvider>().fetchAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final academic = context.watch<AcademicProvider>();
    final auth     = context.watch<AuthProvider>();
    final scheme   = Theme.of(context).colorScheme;
    final analytics = academic.analytics;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => academic.fetchAnalytics(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => academic.fetchAnalytics(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.primary.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  const Icon(Icons.admin_panel_settings_rounded,
                      color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Admin Panel',
                        style: TextStyle(color: Colors.white, fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text('Welcome, ${auth.user?.fullName.split(' ').first ?? 'Admin'}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),

              // Stats grid
              const Text('Overview',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12, mainAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: [
                  _StatCard(label: 'Total Users',
                      value: '${analytics['total_users'] ?? 0}',
                      icon: Icons.people_rounded, color: Colors.blue),
                  _StatCard(label: 'Materials',
                      value: '${analytics['total_materials'] ?? 0}',
                      icon: Icons.picture_as_pdf_rounded, color: Colors.orange),
                  _StatCard(label: 'Downloads',
                      value: '${analytics['total_downloads'] ?? 0}',
                      icon: Icons.download_rounded, color: Colors.green),
                  _StatCard(label: 'Levels',
                      value: '${academic.levels.length}',
                      icon: Icons.layers_rounded, color: Colors.purple),
                ],
              ),
              const SizedBox(height: 20),

              // Top materials
              if (analytics['top_materials'] != null &&
                  (analytics['top_materials'] as List).isNotEmpty) ...[
                const Text('Top Downloads',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...List.generate(
                  (analytics['top_materials'] as List).length,
                  (i) {
                    final m = analytics['top_materials'][i];
                    return _TopMaterialTile(
                      rank: i + 1,
                      title: m['title'] ?? '',
                      course: m['course'] ?? '',
                      downloads: m['downloads'] ?? 0,
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Quick actions
              const Text('Quick Actions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.upload_file_rounded,
                title: 'Upload Material',
                subtitle: 'Add new PDF to any course',
                color: Colors.blue,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const UploadMaterialScreen())),
              ),
              const SizedBox(height: 10),
              _ActionCard(
                icon: Icons.layers_rounded,
                title: 'Manage Levels & Courses',
                subtitle: 'Add or delete levels, semesters, courses',
                color: Colors.purple,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ManageLevelsScreen())),
              ),
              const SizedBox(height: 10),
              _ActionCard(
                icon: Icons.folder_rounded,
                title: 'Manage Materials',
                subtitle: 'Edit titles, delete materials',
                color: Colors.orange,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ManageMaterialsScreen())),
              ),
              const SizedBox(height: 10),
              _ActionCard(
                icon: Icons.campaign_rounded,
                title: 'Send Notification',
                subtitle: 'Broadcast message to all users',
                color: Colors.teal,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SendNotificationScreen())),
              ),
              const SizedBox(height: 10),
              _ActionCard(
                icon: Icons.rate_review_rounded,
                title: 'View Feedback',
                subtitle: 'See user ratings and suggestions',
                color: Colors.pink,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminFeedbackScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value,
      required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TopMaterialTile extends StatelessWidget {
  final int rank, downloads;
  final String title, course;
  const _TopMaterialTile({required this.rank, required this.title,
      required this.course, required this.downloads});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Text('$rank',
              style: const TextStyle(fontWeight: FontWeight.bold,
                  color: Colors.amber))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(course, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        )),
        Text('$downloads ↓',
            style: const TextStyle(fontSize: 12, color: Colors.green,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.title,
      required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          )),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
        ]),
      ),
    );
  }
}
