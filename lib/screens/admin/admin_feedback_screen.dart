import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/admin_stats_provider.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});
  @override State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  List<dynamic> _feedback = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _feedback = await ApiClient.getAdminFeedback();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> fb) async {
    final isRead = fb['is_read'] as bool? ?? false;
    if (isRead) return;
    try {
      await ApiClient.markFeedbackRead(fb['id'] as int);
      setState(() => fb['is_read'] = true);
      if (mounted) context.read<AdminStatsProvider>().fetchStats();
    } catch (_) {}
  }

  double get _avgRating {
    if (_feedback.isEmpty) return 0;
    final total = _feedback.fold<double>(
        0, (s, f) => s + ((f['rating'] as num?)?.toDouble() ?? 0));
    return total / _feedback.length;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Feedback'),
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
                  child: _feedback.isEmpty
                      ? const Center(child: Text('No feedback yet'))
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Summary card
                            Container(
                              padding: const EdgeInsets.all(20),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    scheme.primary,
                                    scheme.primary.withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(children: [
                                Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                  const Text('Average Rating',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Text(_avgRating.toStringAsFixed(1),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.star_rounded,
                                        color: Colors.amber, size: 28),
                                  ]),
                                ]),
                                const Spacer(),
                                Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                  Text('${_feedback.length}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold)),
                                  const Text('Total Reviews',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 12)),
                                ]),
                              ]),
                            ),
                            ..._feedback.map((f) {
                              final fb = Map<String, dynamic>.from(f as Map);
                              return _FeedbackCard(
                                feedback: fb,
                                onRead: () => _markRead(fb),
                              );
                            }),
                          ],
                        ),
                ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final Map<String, dynamic> feedback;
  final VoidCallback onRead;
  const _FeedbackCard({required this.feedback, required this.onRead});

  Color get _typeColor {
    switch (feedback['type']) {
      case 'bug':          return Colors.red;
      case 'feature':      return Colors.blue;
      case 'appreciation': return Colors.green;
      default:             return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rating = (feedback['rating'] as num?)?.toInt() ?? 0;
    final isRead = feedback['is_read'] as bool? ?? false;

    return GestureDetector(
      onTap: onRead,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isRead
                ? Colors.transparent
                : _typeColor.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Row(children: List.generate(
                    5,
                    (i) => Icon(
                          i < rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: i < rating ? Colors.amber : Colors.grey[300],
                          size: 16,
                        ))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(feedback['type'] ?? 'general',
                      style: TextStyle(
                          fontSize: 11,
                          color: _typeColor,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                if (!isRead)
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                        color: _typeColor, shape: BoxShape.circle),
                  ),
                const Spacer(),
                Text(
                  feedback['created_at'] != null
                      ? _fmt(feedback['created_at'])
                      : '',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ]),
              const SizedBox(height: 8),
              Text(feedback['message'] ?? '',
                  style: const TextStyle(fontSize: 13)),
              if (feedback['user_name'] != null) ...[
                const SizedBox(height: 8),
                Text('— ${feedback['user_name']}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
