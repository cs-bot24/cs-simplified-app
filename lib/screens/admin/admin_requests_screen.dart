import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../models/material_request_model.dart';

/// Admin screen showing all student material requests.
/// Filter by status: All / Pending / Fulfilled / Rejected.
/// Tap any request to mark it fulfilled or rejected.
class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  List<MaterialRequestModel> _requests = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // all | pending | fulfilled | rejected

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await ApiClient.getAdminRequests(
        status: _filter == 'all' ? null : _filter,
      );
      setState(() {
        _requests = (raw as List)
            .map((e) => MaterialRequestModel.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not load requests.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(MaterialRequestModel req, String status) async {
    try {
      await ApiClient.updateRequestStatus(req.id, status);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Marked as $status'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: status == 'fulfilled'
              ? Colors.green[700] : Colors.red[700],
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red[700],
        ));
      }
    }
  }

  void _showDetail(MaterialRequestModel req) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: Text(req.topic,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold))),
            _StatusChip(status: req.status),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.school_outlined, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(req.courseName,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(width: 12),
            const Icon(Icons.person_outline, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(req.studentName ?? 'Unknown',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ]),
          if (req.message != null && req.message!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(req.message!,
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
          if (req.status == 'pending') ...[
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateStatus(req, 'rejected');
                  },
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateStatus(req, 'fulfilled');
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Mark Fulfilled'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 8),
          Text(req.formattedDate,
              style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filters = ['all', 'pending', 'fulfilled', 'rejected'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Material Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(children: [
        // Filter chips
        Container(
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f[0].toUpperCase() + f.substring(1)),
                  selected: _filter == f,
                  onSelected: (_) {
                    setState(() => _filter = f);
                    _load();
                  },
                  selectedColor: scheme.primary.withOpacity(0.15),
                  checkmarkColor: scheme.primary,
                ),
              )).toList(),
            ),
          ),
        ),

        // Content
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(mainAxisSize: MainAxisSize.min,
                            children: [
                          Icon(Icons.error_outline,
                              size: 48, color: Colors.red[300]),
                          const SizedBox(height: 12),
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ]),
                      ),
                    )
                  : _requests.isEmpty
                      ? Center(
                          child: Column(mainAxisSize: MainAxisSize.min,
                              children: [
                            Icon(Icons.inbox_outlined,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('No ${_filter == 'all' ? '' : _filter} requests',
                                style: TextStyle(color: Colors.grey[500])),
                          ]),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _requests.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final req = _requests[i];
                              return GestureDetector(
                                onTap: () => _showDetail(req),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: req.statusColor
                                          .withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(
                                          child: Text(req.topic,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  fontSize: 14),
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis),
                                        ),
                                        _StatusChip(status: req.status),
                                      ]),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${req.courseName} · '
                                        '${req.studentName ?? 'Unknown'} · '
                                        '${req.formattedDate}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500]),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ]),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'fulfilled': color = Colors.green; break;
      case 'rejected':  color = Colors.red;   break;
      default:          color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(fontSize: 11, color: color,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}
