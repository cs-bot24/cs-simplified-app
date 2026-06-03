import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/support_provider.dart';
import '../../models/support_ticket_model.dart';
import 'admin_request_detail_screen.dart';

/// Admin tab: Material Requests.
/// Simply filters support_tickets where ticket_type = 'material_request'.
/// No separate backend, no separate table — same proven infrastructure.
class AdminMaterialRequestsScreen extends StatefulWidget {
  const AdminMaterialRequestsScreen({super.key});
  @override State<AdminMaterialRequestsScreen> createState() =>
      _AdminMaterialRequestsScreenState();
}

class _AdminMaterialRequestsScreenState
    extends State<AdminMaterialRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  static const _statuses = [null, 'pending', 'fulfilled', 'closed'];
  static const _labels   = ['All', 'Pending', 'Fulfilled', 'Closed'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupportProvider>().fetchAdminRequests();
    });
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  List<SupportTicketModel> _filtered(
      List<SupportTicketModel> all, int tabIndex) {
    final s = _statuses[tabIndex];
    if (s == null) return all;
    return all.where((r) => r.status == s).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupportProvider>();
    final scheme   = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Material Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                context.read<SupportProvider>().fetchAdminRequests(),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: List.generate(4, (i) {
            final count = i == 0
                ? provider.adminRequests.length
                : _filtered(provider.adminRequests, i).length;
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
                          ? Colors.orange
                          : i == 2
                              ? Colors.green
                              : i == 3
                                  ? Colors.red
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
      body: provider.loadingAdminRequests
          ? const Center(child: CircularProgressIndicator())
          : provider.adminRequestsError != null
              ? _ErrorView(message: provider.adminRequestsError!)
              : TabBarView(
                  controller: _tab,
                  children: List.generate(4, (i) {
                    final requests = _filtered(provider.adminRequests, i);
                    return requests.isEmpty
                        ? _EmptyView(label: _labels[i])
                        : RefreshIndicator(
                            onRefresh: () =>
                                context.read<SupportProvider>()
                                    .fetchAdminRequests(),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: requests.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (ctx, idx) =>
                                  _RequestTile(request: requests[idx]),
                            ),
                          );
                  }),
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
        MaterialPageRoute(
            builder: (_) => AdminRequestDetailScreen(request: request)),
      ).then((_) =>
          context.read<SupportProvider>().fetchAdminRequests()),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(request.studentName ?? 'Unknown Student',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            _StatusBadge(label: request.statusLabel, color: color),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Text('📚', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(request.title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[400]),
            const SizedBox(width: 4),
            Text(_formatDate(request.createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const Spacer(),
            if (request.adminReply == null || request.adminReply!.isEmpty)
              Text('No reply yet',
                  style: TextStyle(fontSize: 11, color: Colors.orange[700]))
            else
              Row(children: [
                Icon(Icons.check_circle_rounded,
                    size: 12, color: Colors.green[600]),
                const SizedBox(width: 3),
                Text('Replied',
                    style: TextStyle(
                        fontSize: 11, color: Colors.green[600])),
              ]),
          ]),
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

// ── Shared widgets ─────────────────────────────────────────────────────────────

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
  final String label;
  const _EmptyView({required this.label});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('📚', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 12),
      Text('No $label requests',
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
        onPressed: () =>
            context.read<SupportProvider>().fetchAdminRequests(),
        child: const Text('Retry'),
      ),
    ]),
  );
}
