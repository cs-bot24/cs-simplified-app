import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/support_provider.dart';
import '../../models/support_ticket_model.dart';
import 'ticket_detail_screen.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});
  @override State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupportProvider>().fetchMyTickets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupportProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<SupportProvider>().fetchMyTickets(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<SupportProvider>().fetchMyTickets(),
        child: provider.loadingMyTickets
            ? const Center(child: CircularProgressIndicator())
            : provider.myTicketsError != null
                ? _ErrorView(message: provider.myTicketsError!)
                : provider.myTickets.isEmpty
                    ? _EmptyView()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.myTickets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) => _TicketTile(
                          ticket: provider.myTickets[i],
                        ),
                      ),
      ),
    );
  }
}

// ── Ticket tile ───────────────────────────────────────────────────────────────

class _TicketTile extends StatelessWidget {
  final SupportTicketModel ticket;
  const _TicketTile({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final (badgeColor, statusLabel) = _statusBadge(ticket.status);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TicketDetailScreen(ticket: ticket)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: badgeColor.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.support_agent_rounded,
                  color: badgeColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ticket.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(children: [
                    _StatusBadge(label: statusLabel, color: badgeColor),
                    const Spacer(),
                    Text(_formatDate(ticket.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ]),
                  if (ticket.adminReply != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.reply_rounded, size: 12, color: Colors.green[600]),
                      const SizedBox(width: 4),
                      Text('Admin replied',
                          style: TextStyle(fontSize: 11, color: Colors.green[600],
                              fontWeight: FontWeight.w500)),
                    ]),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: Colors.grey[400]),
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

// ── Status badge helper ───────────────────────────────────────────────────────

(Color, String) _statusBadge(String status) {
  switch (status) {
    case 'under_review': return (Colors.orange, 'UNDER REVIEW');
    case 'resolved':     return (Colors.green,  'RESOLVED');
    default:             return (Colors.red,     'OPEN');
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 10, color: color,
            fontWeight: FontWeight.bold, letterSpacing: 0.3)),
  );
}

// ── Empty / error views ───────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inbox_outlined, size: 56, color: Colors.grey[300]),
        const SizedBox(height: 14),
        const Text('No support requests yet',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 6),
        Text('Tap "Create Support Request" to get help.',
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.read<SupportProvider>().fetchMyTickets(),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
