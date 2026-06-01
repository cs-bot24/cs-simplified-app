import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/support_provider.dart';
import '../../models/support_ticket_model.dart';
import '../../widgets/app_button.dart';

class AdminTicketDetailScreen extends StatefulWidget {
  final SupportTicketModel ticket;
  const AdminTicketDetailScreen({super.key, required this.ticket});
  @override State<AdminTicketDetailScreen> createState() =>
      _AdminTicketDetailScreenState();
}

class _AdminTicketDetailScreenState extends State<AdminTicketDetailScreen> {
  late final TextEditingController _replyCtrl;
  bool _savingReply   = false;
  bool _savingStatus  = false;
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _replyCtrl      = TextEditingController(text: widget.ticket.adminReply ?? '');
    _currentStatus  = widget.ticket.status;
  }

  @override
  void dispose() { _replyCtrl.dispose(); super.dispose(); }

  // ── Save reply ─────────────────────────────────────────────────────────────
  Future<void> _saveReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) {
      _snack('Reply cannot be empty.', success: false);
      return;
    }
    setState(() => _savingReply = true);
    final err = await context.read<SupportProvider>()
        .replyToTicket(widget.ticket.id, text);
    if (!mounted) return;
    setState(() => _savingReply = false);
    if (err == null) {
      _snack('Reply saved.', success: true);
    } else {
      _snack(err, success: false);
    }
  }

  // ── Change status ──────────────────────────────────────────────────────────
  Future<void> _changeStatus(String status) async {
    setState(() => _savingStatus = true);
    final err = await context.read<SupportProvider>()
        .updateStatus(widget.ticket.id, status);
    if (!mounted) return;
    setState(() {
      _savingStatus  = false;
      if (err == null) _currentStatus = status;
    });
    if (err == null) {
      _snack('Status updated to ${_statusLabel(status)}.', success: true);
    } else {
      _snack(err, success: false);
    }
  }

  void _snack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(success ? Icons.check_circle : Icons.error_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: success ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: Duration(seconds: success ? 3 : 5),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;

    return Scaffold(
      appBar: AppBar(title: const Text('Ticket Detail')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Student info ───────────────────────────────────────────────
            _InfoCard(
              icon: Icons.person_rounded,
              iconColor: Colors.blue,
              title: 'Student',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.studentName ?? 'Unknown',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(t.studentEmail ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Ticket body ────────────────────────────────────────────────
            _InfoCard(
              icon: Icons.support_agent_rounded,
              iconColor: Colors.teal,
              title: t.title,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.message,
                      style: const TextStyle(fontSize: 14, height: 1.6)),
                  const SizedBox(height: 8),
                  Text('Submitted ${_formatDate(t.createdAt)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Status management ──────────────────────────────────────────
            const Text('Change Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            _savingStatus
                ? const Center(child: CircularProgressIndicator())
                : Row(children: [
                    _StatusButton(
                      label: 'Open',
                      color: Colors.red,
                      selected: _currentStatus == 'open',
                      onTap: () => _changeStatus('open'),
                    ),
                    const SizedBox(width: 8),
                    _StatusButton(
                      label: 'Under Review',
                      color: Colors.orange,
                      selected: _currentStatus == 'under_review',
                      onTap: () => _changeStatus('under_review'),
                    ),
                    const SizedBox(width: 8),
                    _StatusButton(
                      label: 'Resolved',
                      color: Colors.green,
                      selected: _currentStatus == 'resolved',
                      onTap: () => _changeStatus('resolved'),
                    ),
                  ]),
            const SizedBox(height: 24),

            // ── Reply ──────────────────────────────────────────────────────
            const Text('Reply Message',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _replyCtrl,
              maxLines: 6,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type your reply to the student...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            AppButton(
              label: 'Save Reply',
              loading: _savingReply,
              onTap: _saveReply,
              icon: Icons.reply_rounded,
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'under_review': return 'Under Review';
      case 'resolved':     return 'Resolved';
      default:             return 'Open';
    }
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

class _StatusButton extends StatelessWidget {
  final String label; final Color color;
  final bool selected; final VoidCallback onTap;
  const _StatusButton({required this.label, required this.color,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : color)),
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  final IconData icon; final Color iconColor;
  final String title; final Widget child;
  const _InfoCard({required this.icon, required this.iconColor,
      required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: iconColor.withOpacity(0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(fontSize: 12, color: iconColor,
                fontWeight: FontWeight.w600),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
      const Divider(height: 14),
      child,
    ]),
  );
}
