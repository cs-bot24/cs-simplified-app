import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotificationProvider>();
      // Refresh the merged feed when user opens the page.
      // markPageOpened() calls fetchNotifications() internally.
      provider.markPageOpened();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final scheme   = Theme.of(context).colorScheme;

    // Filter logic:
    //   all          → everything
    //   unread       → isRead == false
    //   announcement → category == 'announcement'
    //   material     → category == 'material'
    //   system       → category == 'system'
    final filtered = _filter == 'all'
        ? provider.notifications
        : _filter == 'unread'
            ? provider.notifications.where((n) => !n.isRead).toList()
            : provider.notifications.where((n) => n.category == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications'),
            if (provider.unreadCount > 0)
              Text('${provider.unreadCount} unread',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: () => provider.markAllRead(),
              child: Text('Mark all read',
                  style: TextStyle(color: scheme.primary, fontSize: 13)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chips ─────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _FilterChip(label: 'All', value: 'all',
                    selected: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all')),
                const SizedBox(width: 8),
                _FilterChip(label: 'Unread', value: 'unread',
                    selected: _filter == 'unread',
                    onTap: () => setState(() => _filter = 'unread')),
                const SizedBox(width: 8),
                _FilterChip(label: 'Announcements', value: 'announcement',
                    selected: _filter == 'announcement',
                    onTap: () => setState(() => _filter = 'announcement')),
                const SizedBox(width: 8),
                _FilterChip(label: 'Materials', value: 'material',
                    selected: _filter == 'material',
                    onTap: () => setState(() => _filter = 'material')),
                const SizedBox(width: 8),
                _FilterChip(label: 'System', value: 'system',
                    selected: _filter == 'system',
                    onTap: () => setState(() => _filter = 'system')),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── List ─────────────────────────────────────────────────────────
          Expanded(
            child: provider.loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _EmptyState(filter: _filter)
                    : RefreshIndicator(
                        onRefresh: provider.fetchNotifications,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final n = filtered[i];
                            return _NotificationTile(
                              notification: n,
                              onTap: () => provider.markRead(n.id),
                              // Announcements (negative IDs) can't be deleted
                              // from the backend yet — only local dismiss.
                              onDelete: () => n.id < 0
                                  ? _localDismiss(n)
                                  : _confirmDelete(ctx, n),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _localDismiss(NotificationModel n) {
    // For announcements: remove from the local list only.
    context.read<NotificationProvider>().deleteNotification(n.id);
  }

  void _confirmDelete(BuildContext context, NotificationModel n) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('Remove this notification?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<NotificationProvider>().deleteNotification(n.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback onTap, onDelete;
  const _NotificationTile(
      {required this.notification,
      required this.onTap,
      required this.onDelete});
  @override State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _expanded = false;

  IconData get _icon {
    switch (widget.notification.category) {
      case 'material':     return Icons.picture_as_pdf_rounded;
      case 'announcement': return Icons.campaign_rounded;
      case 'system':       return Icons.settings_rounded;
      default:             return Icons.notifications_rounded;
    }
  }

  Color get _color {
    switch (widget.notification.category) {
      case 'material':     return Colors.blue;
      case 'announcement': return Colors.orange;
      case 'system':       return Colors.purple;
      default:             return Colors.green;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 7)     return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  bool get _isTruncated => widget.notification.body.length > 80;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n      = widget.notification;
    return Dismissible(
      key: Key('notif_${n.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: InkWell(
        onTap: () {
          widget.onTap();
          if (_isTruncated) setState(() => _expanded = !_expanded);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: n.isRead ? null : scheme.primary.withOpacity(0.04),
            border: Border(
                bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: _color, size: 20),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(n.title,
                            style: TextStyle(
                                fontWeight: n.isRead
                                    ? FontWeight.w500 : FontWeight.bold,
                                fontSize: 14)),
                      ),
                      if (!n.isRead)
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                              color: scheme.primary, shape: BoxShape.circle),
                        ),
                    ]),
                    const SizedBox(height: 3),
                    // Body — expandable if long
                    Text(
                      n.body,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: _expanded ? null : 2,
                      overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    ),
                    if (_isTruncated) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Text(
                          _expanded ? 'Show less' : 'Read more',
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.primary,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(_timeAgo(n.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                onPressed: widget.onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label, value;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label,
      required this.value,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary
              : scheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color:
                    selected ? Colors.white : scheme.primary)),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  String get _message {
    switch (filter) {
      case 'unread':       return 'You have no unread notifications';
      case 'announcement': return 'No announcements yet';
      case 'material':     return 'No material notifications yet';
      case 'system':       return 'No system notifications yet';
      default:
        return 'Notifications about new materials\nand announcements will appear here';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.notifications_none_rounded,
            size: 72, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(filter == 'unread' ? 'All caught up!' : 'No notifications yet',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(_message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
      ]),
    );
  }
}
