import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/admin_stats_provider.dart';

class AdminContactsScreen extends StatefulWidget {
  const AdminContactsScreen({super.key});
  @override State<AdminContactsScreen> createState() => _AdminContactsScreenState();
}

class _AdminContactsScreenState extends State<AdminContactsScreen> {
  List<dynamic> _messages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _messages = await ApiClient.getAdminContactMessages();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Called when admin expands a message tile — marks it read on backend
  /// and refreshes the dashboard badge count.
  Future<void> _markRead(Map<String, dynamic> msg) async {
    final isRead = msg['is_read'] as bool? ?? false;
    if (isRead) return;
    try {
      await ApiClient.markContactMessageRead(msg['id'] as int);
      setState(() => msg['is_read'] = true);
      // Refresh dashboard stats so the badge number decreases immediately
      if (mounted) {
        context.read<AdminStatsProvider>().fetchStats();
      }
    } catch (_) {}
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'bug':        return Colors.red;
      case 'suggestion': return Colors.blue;
      case 'complaint':  return Colors.orange;
      default:           return Colors.purple;
    }
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'bug':        return Icons.bug_report_outlined;
      case 'suggestion': return Icons.lightbulb_outline;
      case 'complaint':  return Icons.warning_amber_outlined;
      default:           return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Messages'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _messages.isEmpty
                      ? const Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('No messages yet',
                                style: TextStyle(color: Colors.grey, fontSize: 16)),
                          ]))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final m = Map<String, dynamic>.from(_messages[i] as Map);
                            _messages[i] = m; // ensure mutable reference
                            final type    = m['type'] as String? ?? 'question';
                            final isRead  = m['is_read'] as bool? ?? false;
                            final color   = _typeColor(type);
                            return Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isRead
                                      ? Colors.grey.withOpacity(0.15)
                                      : color.withOpacity(0.35),
                                  width: isRead ? 1 : 1.5,
                                ),
                              ),
                              child: ExpansionTile(
                                onExpansionChanged: (expanded) {
                                  if (expanded) _markRead(m);
                                },
                                leading: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(isRead ? 0.07 : 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(_typeIcon(type),
                                          color: color.withOpacity(isRead ? 0.5 : 1.0),
                                          size: 20),
                                    ),
                                    if (!isRead)
                                      Positioned(
                                        top: -2, right: -2,
                                        child: Container(
                                          width: 10, height: 10,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Theme.of(context).cardColor,
                                                width: 1.5),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  m['subject'] ?? 'No subject',
                                  style: TextStyle(
                                      fontWeight: isRead
                                          ? FontWeight.w500
                                          : FontWeight.bold,
                                      fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Row(children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(type,
                                        style: TextStyle(fontSize: 11,
                                            color: color,
                                            fontWeight: FontWeight.w500)),
                                  ),
                                  const SizedBox(width: 8),
                                  if (m['created_at'] != null)
                                    Text(
                                      _formatDate(m['created_at']),
                                      style: TextStyle(fontSize: 11,
                                          color: Colors.grey[500]),
                                    ),
                                ]),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Divider(),
                                        const SizedBox(height: 8),
                                        Text(m['message'] ?? '',
                                            style: const TextStyle(
                                                fontSize: 14, height: 1.5)),
                                        if (m['user_id'] != null) ...[
                                          const SizedBox(height: 12),
                                          Text('User ID: ${m['user_id']}',
                                              style: TextStyle(fontSize: 12,
                                                  color: Colors.grey[500])),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}
