import 'package:flutter/material.dart';
import '../../models/support_ticket_model.dart';

class TicketDetailScreen extends StatelessWidget {
  final SupportTicketModel ticket;
  const TicketDetailScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    final (badgeColor, statusLabel) = _statusBadge(ticket.status);

    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status + date row ──────────────────────────────────────────
            Row(children: [
              _StatusBadge(label: statusLabel, color: badgeColor),
              const Spacer(),
              Text(_formatDate(ticket.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ]),
            const SizedBox(height: 14),

            // ── Title ──────────────────────────────────────────────────────
            Text(ticket.title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // ── Original message ───────────────────────────────────────────
            _Section(
              icon: Icons.person_outline_rounded,
              iconColor: Colors.blue,
              title: 'Your Message',
              child: Text(ticket.message,
                  style: const TextStyle(fontSize: 14, height: 1.6)),
            ),
            const SizedBox(height: 16),

            // ── Admin reply ────────────────────────────────────────────────
            _Section(
              icon: Icons.support_agent_rounded,
              iconColor: Colors.teal,
              title: 'Admin Reply',
              child: ticket.adminReply != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ticket.adminReply!,
                            style: const TextStyle(fontSize: 14, height: 1.6)),
                        if (ticket.repliedAt != null) ...[
                          const SizedBox(height: 8),
                          Text('Replied ${_formatDate(ticket.repliedAt!)}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500])),
                        ],
                      ],
                    )
                  : Row(children: [
                      Icon(Icons.schedule_rounded,
                          size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 6),
                      Text('No admin reply yet.',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[500],
                              fontStyle: FontStyle.italic)),
                    ]),
            ),
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
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 11, color: color,
            fontWeight: FontWeight.bold, letterSpacing: 0.4)),
  );
}

class _Section extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _Section({
    required this.icon, required this.iconColor,
    required this.title, required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: iconColor.withOpacity(0.18)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: iconColor)),
        ]),
        const Divider(height: 16),
        child,
      ],
    ),
  );
}
