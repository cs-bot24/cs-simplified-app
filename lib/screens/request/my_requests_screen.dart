import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/support_provider.dart';
import '../../models/support_ticket_model.dart';
import 'request_detail_screen.dart';

/// Student view of all their submitted material requests.
class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});
  @override State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupportProvider>().fetchMyRequests();
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
            onPressed: () => context.read<SupportProvider>().fetchMyRequests(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<SupportProvider>().fetchMyRequests(),
        child: provider.loadingMyRequests
            ? const Center(child: CircularProgressIndicator())
            : provider.myRequestsError != null
                ? _ErrorView(message: provider.myRequestsError!)
                : provider.myRequests.isEmpty
                    ? _EmptyView()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.myRequests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) =>
                            _RequestTile(request: provider.myRequests[i]),
                      ),
      ),
    );
  }
}

// ── Request tile ──────────────────────────────────────────────────────────────

class _RequestTile extends StatelessWidget {
  final SupportTicketModel request;
  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final color = request.statusColor;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RequestDetailScreen(request: request)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
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
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('📚',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, height: 2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(children: [
                    _StatusBadge(label: request.statusLabel, color: color),
                    const Spacer(),
                    Text(_formatDate(request.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ]),
                  if (request.adminReply != null && request.adminReply!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.reply_rounded, size: 12, color: Colors.teal[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(request.adminReply!,
                            style: TextStyle(fontSize: 11, color: Colors.teal[600],
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
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

// ── Widgets ───────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label; final Color color;
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

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('📚', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 14),
      const Text('No requests yet',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      const SizedBox(height: 6),
      Text("Tap 'Request Material' to ask the admin.",
          style: TextStyle(fontSize: 13, color: Colors.grey[500])),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.read<SupportProvider>().fetchMyRequests(),
          child: const Text('Retry'),
        ),
      ]),
    ),
  );
}
