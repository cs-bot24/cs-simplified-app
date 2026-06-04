import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/support_provider.dart';
import '../faq/faq_screen.dart';
import 'create_ticket_screen.dart';
import 'my_tickets_screen.dart';
import '../request/request_material_screen.dart';
import '../request/my_requests_screen.dart';

class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({super.key});
  @override State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<SupportProvider>();
      p.fetchMyTickets();
      p.fetchMyRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme   = Theme.of(context).colorScheme;
    final provider = context.watch<SupportProvider>();

    // Unread counts: tickets/requests that have an admin reply but haven't
    // been opened yet. We track this via hasUnreadReply on the model.
    final unreadTickets  = provider.myTickets
        .where((t) => t.adminReply != null && t.adminReply!.isNotEmpty && !t.isReplySeen)
        .length;
    final unreadRequests = provider.myRequests
        .where((r) => r.adminReply != null && r.adminReply!.isNotEmpty && !r.isReplySeen)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Support Center')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header banner ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  scheme.primary.withOpacity(0.85),
                  scheme.primary.withOpacity(0.55),
                ]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.support_agent_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How can we help?',
                          style: TextStyle(color: Colors.white, fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 3),
                      Text('Submit a ticket and we\'ll get back to you.',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                ),
              ]),
            ),
            const SizedBox(height: 28),

            // ── Action cards ───────────────────────────────────────────────
            _SupportCard(
              icon: Icons.quiz_rounded,
              color: Colors.indigo,
              title: 'Frequently Asked Questions',
              subtitle: 'Quick answers to common questions',
              badge: 0,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const FaqScreen())),
            ),
            const SizedBox(height: 14),
            _SupportCard(
              icon: Icons.add_circle_outline_rounded,
              color: scheme.primary,
              title: 'Create Support Request',
              subtitle: 'Describe your issue and we\'ll review it',
              badge: 0,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CreateTicketScreen()))
                  .then((_) => context.read<SupportProvider>().fetchMyTickets()),
            ),
            const SizedBox(height: 14),
            _SupportCard(
              icon: Icons.inbox_rounded,
              color: Colors.teal,
              title: 'My Support Requests',
              subtitle: 'View history and track your tickets',
              badge: unreadTickets,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MyTicketsScreen()))
                  .then((_) => context.read<SupportProvider>().fetchMyTickets()),
            ),
            const SizedBox(height: 14),
            _SupportCard(
              icon: Icons.menu_book_rounded,
              color: Colors.orange,
              title: 'Request a Material',
              subtitle: 'Ask admin to upload missing materials',
              badge: 0,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const RequestMaterialScreen()))
                  .then((_) => context.read<SupportProvider>().fetchMyRequests()),
            ),
            const SizedBox(height: 14),
            _SupportCard(
              icon: Icons.history_rounded,
              color: Colors.deepOrange,
              title: 'My Material Requests',
              subtitle: 'Track your material request history',
              badge: unreadRequests,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MyRequestsScreen()))
                  .then((_) => context.read<SupportProvider>().fetchMyRequests()),
            ),

            const SizedBox(height: 32),

            // ── Info section ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.15)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, color: Colors.blue[400], size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Tickets are typically reviewed within 24 hours. '
                    'You\'ll receive a notification when admin replies.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Support card with optional unread badge ───────────────────────────────────

class _SupportCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final int badge;
  final VoidCallback onTap;

  const _SupportCard({
    required this.icon, required this.color,
    required this.title, required this.subtitle,
    required this.badge, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 14, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ]),
            ),
            if (badge > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$badge',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
            ],
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: color.withOpacity(0.5)),
          ]),
        ),
      ),
    );
  }
}
