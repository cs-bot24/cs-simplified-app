import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/support_provider.dart';
import '../../models/support_ticket_model.dart';
import '../../widgets/app_button.dart';

/// Admin detail screen for a single material request.
/// Matches the architecture of AdminTicketDetailScreen.
class AdminRequestDetailScreen extends StatefulWidget {
  final SupportTicketModel request;
  const AdminRequestDetailScreen({super.key, required this.request});
  @override State<AdminRequestDetailScreen> createState() =>
      _AdminRequestDetailScreenState();
}

class _AdminRequestDetailScreenState
    extends State<AdminRequestDetailScreen> {
  late final TextEditingController _replyCtrl;
  bool _savingReply  = false;
  bool _savingStatus = false;
  bool _deleting     = false;
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _replyCtrl     = TextEditingController(
        text: widget.request.adminReply ?? '');
    _currentStatus = widget.request.status;
  }

  @override
  void dispose() { _replyCtrl.dispose(); super.dispose(); }

  // ── Save reply ─────────────────────────────────────────────────────────────
  Future<void> _saveReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) { _snack('Reply cannot be empty.', success: false); return; }
    setState(() => _savingReply = true);
    final err = await context.read<SupportProvider>()
        .replyToRequest(widget.request.id, text);
    if (!mounted) return;
    setState(() => _savingReply = false);
    _snack(err == null ? 'Reply saved.' : err, success: err == null);
  }

  // ── Change status ──────────────────────────────────────────────────────────
  Future<void> _changeStatus(String status) async {
    setState(() => _savingStatus = true);
    final err = await context.read<SupportProvider>()
        .updateRequestStatus(widget.request.id, status);
    if (!mounted) return;
    setState(() {
      _savingStatus = false;
      if (err == null) _currentStatus = status;
    });
    _snack(err == null
        ? 'Status updated to ${_statusLabel(status)}.'
        : err, success: err == null);
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text(
            'This request will be permanently removed. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _deleting = true);
    final err = await context.read<SupportProvider>()
        .deleteRequest(widget.request.id);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (err == null) {
      Navigator.pop(context); // go back to list
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
    final r = widget.request;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Detail'),
        actions: [
          if (_deleting)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: _confirmDelete,
              tooltip: 'Delete Request',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Student info ───────────────────────────────────────────────
          _InfoCard(
            icon: Icons.person_rounded, iconColor: Colors.blue,
            title: 'Requested By',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.studentName ?? 'Unknown',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text(r.studentEmail ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Request body ───────────────────────────────────────────────
          _InfoCard(
            icon: Icons.menu_book_rounded, iconColor: Colors.orange,
            title: r.title,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (r.message.isNotEmpty) ...[
                Text(r.message,
                    style: const TextStyle(fontSize: 14, height: 1.6)),
                const SizedBox(height: 8),
              ],
              Row(children: [
                Icon(Icons.access_time_rounded,
                    size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text('Requested ${_formatDate(r.createdAt)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
            ]),
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
                    label: '🟡 Pending',
                    color: Colors.orange,
                    selected: _currentStatus == 'pending',
                    onTap: () => _changeStatus('pending'),
                  ),
                  const SizedBox(width: 8),
                  _StatusButton(
                    label: '🟢 Fulfilled',
                    color: Colors.green,
                    selected: _currentStatus == 'fulfilled',
                    onTap: () => _changeStatus('fulfilled'),
                  ),
                  const SizedBox(width: 8),
                  _StatusButton(
                    label: '🔴 Closed',
                    color: Colors.red,
                    selected: _currentStatus == 'closed',
                    onTap: () => _changeStatus('closed'),
                  ),
                ]),
          const SizedBox(height: 24),

          // ── Reply ──────────────────────────────────────────────────────
          const Text('Reply to Student',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          TextFormField(
            controller: _replyCtrl,
            maxLines: 6,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Type your reply...\n'
                  'e.g. Past questions have been uploaded.\n'
                  'Check Materials > MTH 104.',
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
        ]),
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'fulfilled': return 'Fulfilled';
      case 'closed':    return 'Closed';
      default:          return 'Pending';
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
        Expanded(
          child: Text(title,
              style: TextStyle(fontSize: 12, color: iconColor,
                  fontWeight: FontWeight.w600),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ]),
      const Divider(height: 14),
      child,
    ]),
  );
}
