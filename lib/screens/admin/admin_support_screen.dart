import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/support_provider.dart';
import '../../models/support_ticket_model.dart';
import 'admin_ticket_detail_screen.dart';

class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});
  @override State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  static const _statuses = [null, 'open', 'under_review', 'resolved'];
  static const _labels   = ['All', 'Open', 'Under Review', 'Resolved'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupportProvider>().fetchAdminTickets();
    });
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  List<SupportTicketModel> _filtered(
      List<SupportTicketModel> all, int tabIndex) {
    final status = _statuses[tabIndex];
    if (status == null) return all;
    return all.where((t) => t.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupportProvider>();
    final scheme   = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<SupportProvider>().fetchAdminTickets(),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: List.generate(4, (i) {
            final count = i == 0
                ? provider.adminTickets.length
                : _filtered(provider.adminTickets, i).length;
            return Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_labels[i]),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: i == 1
                          ? Colors.red
                          : i == 2
                              ? Colors.orange
                              : scheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
            );
          }),
        ),
      ),
      body: provider.loadingAdmin
          ? const Center(child: CircularProgressIndicator())
          : provider.adminError != null
              ? _ErrorView(message: provider.adminError!)
              : TabBarView(
                  controller: _tab,
                  children: List.generate(4, (i) {
                    final tickets = _filtered(provider.adminTickets, i);
                    return tickets.isEmpty
                        ? _EmptyView(tabLabel: _labels[i])
                        : RefreshIndicator(
                            onRefresh: () => context
                                .read<SupportProvider>()
                                .fetchAdminTickets(),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: tickets.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (ctx, idx) =>
                                  _AdminTicketTile(ticket: tickets[idx]),
                            ),
                          );
                  }),
                ),
    );
  }
}

// ── Admin ticket tile ─────────────────────────────────────────────────────────

class _AdminTicketTile extends StatelessWidget {
  final SupportTicketModel ticket;
  const _AdminTicketTile({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final (badgeColor, statusLabel) = _statusBadge(ticket.status);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AdminTicketDetailScreen(ticket: ticket)),
      ).then((_) =>
          context.read<SupportProvider>().fetchAdminTickets()),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: badgeColor.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(ticket.studentName ?? 'Unknown Student',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              _StatusBadge(label: statusLabel, color: badgeColor),
            ]),
            const SizedBox(height: 4),
            Text(ticket.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.access_time_rounded,
                  size: 12, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(_formatDate(ticket.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const Spacer(),
              if (ticket.adminReply == null)
                Text('No reply yet',
                    style: TextStyle(fontSize: 11, color: Colors.orange[700]))
              else
                Row(children: [
                  Icon(Icons.check_circle_rounded,
                      size: 12, color: Colors.green[600]),
                  const SizedBox(width: 3),
                  Text('Replied',
                      style: TextStyle(fontSize: 11, color: Colors.green[600])),
                ]),
            ]),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 7)     return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

(Color, String) _statusBadge(String status) {
  switch (status) {
    case 'under_review': return (Colors.orange, 'UNDER REVIEW');
    case 'resolved':     return (Colors.green,  'RESOLVED');
    default:             return (Colors.red,     'OPEN');
  }
}

class _StatusBadge extends StatelessWidget {
  final String label; final Color color;
  const _StatusBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 9, color: color,
            fontWeight: FontWeight.bold, letterSpacing: 0.3)),
  );
}

class _EmptyView extends StatelessWidget {
  final String tabLabel;
  const _EmptyView({required this.tabLabel});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inbox_outlined, size: 52, color: Colors.grey[300]),
      const SizedBox(height: 12),
      Text('No $tabLabel tickets',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.red),
      const SizedBox(height: 10),
      Text(message, style: TextStyle(color: Colors.grey[600])),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => context.read<SupportProvider>().fetchAdminTickets(),
        child: const Text('Retry'),
      ),
    ]),
  );
}
