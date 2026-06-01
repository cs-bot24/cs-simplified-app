import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_stats_provider.dart';
import '../../providers/auth_provider.dart';
import 'manage_levels_screen.dart';
import 'manage_materials_screen.dart';
import 'upload_material_screen.dart';
import 'send_notification_screen.dart';
import 'admin_feedback_screen.dart';
import 'admin_contacts_screen.dart';
import 'admin_requests_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _fetchedOnce = false;

  @override
  void initState() {
    super.initState();
    // addPostFrameCallback fires after the first frame.
    // This covers the case where the admin tab is the active tab on load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint('[AdminDashboard] initState fetchStats');
        context.read<AdminStatsProvider>().fetchStats();
        _fetchedOnce = true;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies fires when the widget is first inserted into
    // the tree AND every time an inherited widget it depends on changes.
    // This ensures fetchStats runs even when the tab is switched to later.
    if (!_fetchedOnce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          debugPrint('[AdminDashboard] didChangeDependencies fetchStats');
          context.read<AdminStatsProvider>().fetchStats();
          _fetchedOnce = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats  = context.watch<AdminStatsProvider>();
    final auth   = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _fetchedOnce = false;
              context.read<AdminStatsProvider>().fetchStats();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AdminStatsProvider>().fetchStats(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Error banner — shows actual error message on screen ────────
              if (stats.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(stats.error!,
                          style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                    TextButton(
                      onPressed: () => context.read<AdminStatsProvider>().fetchStats(),
                      child: const Text('Retry', style: TextStyle(fontSize: 12)),
                    ),
                  ]),
                ),

              // Welcome banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.primary.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  const Icon(Icons.admin_panel_settings_rounded,
                      color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Admin Panel', style: TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Welcome, ${auth.user?.fullName.split(' ').first ?? 'Admin'}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),

              // Stats grid
              const Text('Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              stats.loading
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                : GridView.count(
                    crossAxisCount: 2, shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12, mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      _StatCard(label: 'Total Users', value: '${stats.totalUsers}',
                          icon: Icons.people_rounded, color: Colors.blue),
                      _StatCard(label: 'Active (7d)', value: '${stats.activeUsers7d}',
                          icon: Icons.trending_up_rounded, color: Colors.teal),
                      _StatCard(label: 'Materials', value: '${stats.totalMaterials}',
                          icon: Icons.picture_as_pdf_rounded, color: Colors.orange),
                      _StatCard(label: 'Downloads Today', value: '${stats.downloadsToday}',
                          icon: Icons.download_rounded, color: Colors.green),
                      _StatCard(label: 'Downloads (7d)', value: '${stats.downloadsWeek}',
                          icon: Icons.bar_chart_rounded, color: Colors.purple),
                      _StatCard(label: 'Pending Requests',
                          value: '${stats.pendingRequests}',
                          icon: Icons.inbox_rounded,
                          color: stats.pendingRequests > 0 ? Colors.red : Colors.grey),
                    ],
                  ),
              const SizedBox(height: 20),

              // Attention badges
              if (!stats.loading && (stats.pendingRequests > 0 ||
                  stats.unreadFeedback > 0 || stats.unreadMessages > 0)) ...[
                const Text('Needs Attention', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(children: [
                  if (stats.pendingRequests > 0) Expanded(child: _BadgeCard(
                    label: 'Requests', count: stats.pendingRequests,
                    icon: Icons.inbox_rounded, color: Colors.orange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const AdminRequestsScreen())),
                  )),
                  if (stats.pendingRequests > 0 && stats.unreadFeedback > 0)
                    const SizedBox(width: 10),
                  if (stats.unreadFeedback > 0) Expanded(child: _BadgeCard(
                    label: 'Feedback', count: stats.unreadFeedback,
                    icon: Icons.rate_review_rounded, color: Colors.pink,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const AdminFeedbackScreen())),
                  )),
                  if (stats.unreadMessages > 0) ...[
                    if (stats.pendingRequests > 0 || stats.unreadFeedback > 0)
                      const SizedBox(width: 10),
                    Expanded(child: _BadgeCard(
                      label: 'Messages', count: stats.unreadMessages,
                      icon: Icons.mail_rounded, color: Colors.teal,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const AdminContactsScreen())),
                    )),
                  ],
                ]),
                const SizedBox(height: 20),
              ],

              // Recent uploads
              if (stats.recentUploads.isNotEmpty) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Recent Uploads', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const ManageMaterialsScreen())),
                    child: Text('See All', style: TextStyle(
                        fontSize: 13, color: scheme.primary, fontWeight: FontWeight.w500)),
                  ),
                ]),
                const SizedBox(height: 12),
                ...stats.recentUploads.map((m) => _RecentTile(
                    title: m['title'] ?? '', course: m['course'] ?? '',
                    uploadedAt: m['uploaded_at'] ?? '')),
                const SizedBox(height: 20),
              ],

              // Top downloads
              if (stats.topMaterials.isNotEmpty) ...[
                const Text('Top Downloads', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...List.generate(stats.topMaterials.length, (i) {
                  final m = stats.topMaterials[i];
                  return _TopMaterialTile(rank: i + 1,
                      title: m['title'] ?? '', course: m['course'] ?? '',
                      downloads: m['downloads'] ?? 0);
                }),
                const SizedBox(height: 20),
              ],

              // ── Pending Requests Preview (latest 3) ────────────────────
              if (!stats.loading && stats.pendingRequestsPreview.isNotEmpty) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Pending Requests',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const AdminRequestsScreen())),
                    child: Text('View All',
                        style: TextStyle(
                            fontSize: 13,
                            color: scheme.primary,
                            fontWeight: FontWeight.w500)),
                  ),
                ]),
                const SizedBox(height: 12),
                ...stats.pendingRequestsPreview.map((r) => _PendingRequestPreviewTile(
                  studentName: r['student_name'] ?? 'Student',
                  courseName:  r['course_name']  ?? '',
                  topic:       r['topic']        ?? '',
                  createdAt:   r['created_at']   ?? '',
                )),
                const SizedBox(height: 20),
              ],

              // Quick actions
              const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _ActionCard(icon: Icons.upload_file_rounded, title: 'Upload Material',
                  subtitle: 'Add new PDF to any course', color: Colors.blue,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const UploadMaterialScreen()))),
              const SizedBox(height: 10),
              _ActionCard(icon: Icons.layers_rounded, title: 'Manage Levels & Courses',
                  subtitle: 'Add or edit levels, semesters, courses', color: Colors.purple,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const ManageLevelsScreen()))),
              const SizedBox(height: 10),
              _ActionCard(icon: Icons.folder_rounded, title: 'Manage Materials',
                  subtitle: 'Edit titles, delete materials', color: Colors.orange,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const ManageMaterialsScreen()))),
              const SizedBox(height: 10),
              _ActionCard(icon: Icons.inbox_rounded, title: 'Material Requests',
                  subtitle: 'View and resolve student requests', color: Colors.amber[700]!,
                  badge: stats.pendingRequests,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const AdminRequestsScreen()))),
              const SizedBox(height: 10),
              _ActionCard(icon: Icons.campaign_rounded, title: 'Send Notification',
                  subtitle: 'Broadcast message to all students', color: Colors.teal,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const SendNotificationScreen()))),
              const SizedBox(height: 10),
              _ActionCard(icon: Icons.rate_review_rounded, title: 'View Feedback',
                  subtitle: 'See user ratings and suggestions', color: Colors.pink,
                  badge: stats.unreadFeedback,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const AdminFeedbackScreen()))),
              const SizedBox(height: 10),
              _ActionCard(icon: Icons.mail_outline_rounded, title: 'User Messages',
                  subtitle: 'View contact messages from students', color: Colors.teal,
                  badge: stats.unreadMessages,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const AdminContactsScreen()))),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 24),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );
}

class _BadgeCard extends StatelessWidget {
  final String label; final int count; final IconData icon;
  final Color color; final VoidCallback onTap;
  const _BadgeCard({required this.label, required this.count, required this.icon,
      required this.color, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Row(children: [
        Icon(icon, color: color, size: 20), const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 13,
            fontWeight: FontWeight.w600, color: color),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: const TextStyle(color: Colors.white,
              fontSize: 12, fontWeight: FontWeight.bold))),
      ]),
    ),
  );
}

class _RecentTile extends StatelessWidget {
  final String title, course, uploadedAt;
  const _RecentTile({required this.title, required this.course, required this.uploadedAt});
  @override Widget build(BuildContext context) {
    String t = uploadedAt;
    try {
      final dt = DateTime.parse(uploadedAt).toLocal();
      final d = DateTime.now().difference(dt);
      if (d.inHours < 24) t = '${d.inHours}h ago';
      else if (d.inDays < 7) t = '${d.inDays}d ago';
      else t = uploadedAt.split('T').first;
    } catch (_) {}
    return Container(margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.blue, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('$course · $t', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ])),
      ]),
    );
  }
}

class _TopMaterialTile extends StatelessWidget {
  final int rank, downloads; final String title, course;
  const _TopMaterialTile({required this.rank, required this.title,
      required this.course, required this.downloads});
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Container(width: 32, height: 32,
        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text('$rank', style: const TextStyle(
            fontWeight: FontWeight.bold, color: Colors.amber)))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(course, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ])),
      Text('$downloads ↓', style: const TextStyle(fontSize: 12,
          color: Colors.green, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _ActionCard extends StatelessWidget {
  final IconData icon; final String title, subtitle;
  final Color color; final VoidCallback onTap; final int badge;
  const _ActionCard({required this.icon, required this.title, required this.subtitle,
      required this.color, required this.onTap, this.badge = 0});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Container(width: 48, height: 48,
          decoration: BoxDecoration(color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 24)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ])),
        if (badge > 0)
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
            child: Text('$badge', style: const TextStyle(color: Colors.white,
                fontSize: 11, fontWeight: FontWeight.bold)))
        else
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
      ]),
    ),
  );
}

class _PendingRequestPreviewTile extends StatelessWidget {
  final String studentName, courseName, topic, createdAt;
  const _PendingRequestPreviewTile({
    required this.studentName,
    required this.courseName,
    required this.topic,
    required this.createdAt,
  });

  String get _timeAgo {
    try {
      final dt   = DateTime.parse(createdAt).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      if (diff.inDays < 7)     return '${diff.inDays}d ago';
      return createdAt.split('T').first;
    } catch (_) {
      return createdAt.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.amber.withOpacity(0.25)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.inbox_rounded, color: Colors.amber, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(studentName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text('$courseName · $topic',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_timeAgo,
              style: const TextStyle(fontSize: 10, color: Colors.orange)),
        ),
      ],
    ),
  );
}
