import 'package:flutter/material.dart';
import '../../models/support_ticket_model.dart';

/// Student view of a single material request detail.
class RequestDetailScreen extends StatelessWidget {
  final SupportTicketModel request;
  const RequestDetailScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final color = request.statusColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status + date ──────────────────────────────────────────────
            Row(children: [
              _StatusBadge(label: request.statusLabel, color: color),
              const Spacer(),
              Text(_formatDate(request.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ]),
            const SizedBox(height: 14),

            // ── Title ──────────────────────────────────────────────────────
            Row(children: [
              const Text('📚', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(request.title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Your request message ───────────────────────────────────────
            if (request.message.isNotEmpty) ...[
              _Section(
                icon: Icons.person_outline_rounded,
                iconColor: Colors.blue,
                title: 'Your Request',
                child: Text(request.message,
                    style: const TextStyle(fontSize: 14, height: 1.6)),
              ),
              const SizedBox(height: 16),
            ],

            // ── Admin reply ────────────────────────────────────────────────
            _Section(
              icon: Icons.support_agent_rounded,
              iconColor: Colors.teal,
              title: 'Admin Reply',
              child: request.adminReply != null && request.adminReply!.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(request.adminReply!,
                            style: const TextStyle(fontSize: 14, height: 1.6)),
                        if (request.repliedAt != null) ...[
                          const SizedBox(height: 8),
                          Text('Replied ${_formatDate(request.repliedAt!)}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500])),
                        ],
                      ],
                    )
                  : Row(children: [
                      Icon(Icons.schedule_rounded,
                          size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 6),
                      Text('No reply yet.',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[500],
                              fontStyle: FontStyle.italic)),
                    ]),
            ),

            // ── Status meaning ────────────────────────────────────────────
            const SizedBox(height: 20),
            _StatusGuide(),
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
        Text(title,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: iconColor)),
      ]),
      const Divider(height: 16),
      child,
    ]),
  );
}

class _StatusGuide extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.grey.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Status Guide',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: Colors.grey[600])),
        const SizedBox(height: 10),
        _guideRow('🟡', 'Pending', 'Your request is awaiting admin review.'),
        const SizedBox(height: 6),
        _guideRow('🟢', 'Fulfilled', 'Material has been uploaded. Check Materials section.'),
        const SizedBox(height: 6),
        _guideRow('🔴', 'Closed', 'Request was closed by admin.'),
      ],
    ),
  );

  Widget _guideRow(String emoji, String label, String desc) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(emoji, style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 8),
      Expanded(
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
            children: [
              TextSpan(text: '$label — ',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: desc),
            ],
          ),
        ),
      ),
    ],
  );
}
