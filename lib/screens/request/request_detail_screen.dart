import 'package:flutter/material.dart';
import '../../models/support_ticket_model.dart';

/// Student view of a single material request detail.
/// Marks the reply as seen when opened, clearing the unread badge.
class RequestDetailScreen extends StatefulWidget {
  final SupportTicketModel request;
  const RequestDetailScreen({super.key, required this.request});
  @override State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Mark reply as seen so the badge clears on the support center
    if (widget.request.adminReply != null && widget.request.adminReply!.isNotEmpty) {
      widget.request.markReplySeen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r     = widget.request;
    final color = r.statusColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Status + date ────────────────────────────────────────────────
          Row(children: [
            _StatusBadge(label: r.statusLabel, color: color),
            const Spacer(),
            Text(_formatDate(r.createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ]),
          const SizedBox(height: 14),

          // ── Title ────────────────────────────────────────────────────────
          Row(children: [
            const Text('📚', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(child: Text(r.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 16),

          // ── Your request ─────────────────────────────────────────────────
          if (r.message.isNotEmpty) ...[
            _Section(
              icon: Icons.person_outline_rounded, iconColor: Colors.blue,
              title: 'Your Request',
              child: Text(r.message,
                  style: const TextStyle(fontSize: 14, height: 1.6)),
            ),
            const SizedBox(height: 16),
          ],

          // ── Admin reply ──────────────────────────────────────────────────
          _Section(
            icon: Icons.support_agent_rounded, iconColor: Colors.teal,
            title: 'Admin Reply',
            child: r.adminReply != null && r.adminReply!.isNotEmpty
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Full reply — no truncation
                    Text(r.adminReply!,
                        style: const TextStyle(fontSize: 14, height: 1.6)),
                    if (r.repliedAt != null) ...[
                      const SizedBox(height: 8),
                      Text('Replied ${_formatDate(r.repliedAt!)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ])
                : Row(children: [
                    Icon(Icons.schedule_rounded, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text('No reply yet.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500],
                            fontStyle: FontStyle.italic)),
                  ]),
          ),
        ]),
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

// ── Widgets ───────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label; final Color color;
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
  final IconData icon; final Color iconColor;
  final String title; final Widget child;
  const _Section({required this.icon, required this.iconColor,
      required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: iconColor.withOpacity(0.18)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: iconColor)),
      ]),
      const Divider(height: 16),
      child,
    ]),
  );
}
