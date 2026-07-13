import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/offline_provider.dart';
import '../../services/offline/storage_analytics.dart';

/// Settings → Offline Materials → Storage (also reachable from the Offline
/// Library app bar). Usage stats + destructive cleanup actions, each
/// gated behind a confirmation dialog.
class StorageManagementScreen extends StatefulWidget {
  const StorageManagementScreen({super.key});

  @override
  State<StorageManagementScreen> createState() => _StorageManagementScreenState();
}

class _StorageManagementScreenState extends State<StorageManagementScreen> {
  StorageSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await context.read<OfflineProvider>().loadStorageSnapshot();
    if (mounted) setState(() => _snapshot = snap);
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _run(Future<int> Function() action, String confirmTitle, String confirmMessage) async {
    if (!await _confirm(confirmTitle, confirmMessage)) return;
    final n = await action();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(n == 0 ? 'Nothing to remove' : 'Removed $n material${n == 1 ? '' : 's'}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OfflineProvider>();
    final s = _snapshot;

    return Scaffold(
      appBar: AppBar(title: const Text('Offline Storage')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _UsageCard(snapshot: s),
                  const SizedBox(height: 20),
                  if (s.byCourse.isNotEmpty) ...[
                    const _SectionLabel('Storage by Course'),
                    _CourseBreakdown(entries: s.byCourse, totalBytes: s.usedBytes),
                    const SizedBox(height: 20),
                  ],
                  if (s.largestFiles.isNotEmpty) ...[
                    const _SectionLabel('Largest Files'),
                    ...s.largestFiles.map((m) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.picture_as_pdf_rounded),
                          title: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13)),
                          trailing: Text(m.formattedSize,
                              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        )),
                    const SizedBox(height: 12),
                  ],
                  const _SectionLabel('Cleanup'),
                  _CleanupTile(
                    icon: Icons.done_all_rounded,
                    title: 'Delete completed courses',
                    subtitle: 'Removes materials from courses you\u2019ve fully read',
                    onTap: () => _run(
                      provider.deleteCompletedCourses,
                      'Delete completed courses?',
                      'Every material in a fully-read course will be removed from this device.',
                    ),
                  ),
                  _CleanupTile(
                    icon: Icons.visibility_off_outlined,
                    title: 'Delete unused materials',
                    subtitle: 'Removes downloads you\u2019ve never opened',
                    onTap: () => _run(
                      provider.deleteUnusedMaterials,
                      'Delete unused materials?',
                      'Materials you\u2019ve never opened will be removed from this device.',
                    ),
                  ),
                  _CleanupTile(
                    icon: Icons.history_rounded,
                    title: 'Delete old downloads',
                    subtitle: 'Removes materials not opened in 60+ days',
                    onTap: () => _run(
                      provider.deleteOldDownloads,
                      'Delete old downloads?',
                      'Materials not opened in the last 60 days will be removed from this device.',
                    ),
                  ),
                  _CleanupTile(
                    icon: Icons.cleaning_services_outlined,
                    title: 'Clear cache',
                    subtitle: 'Clears completed-download history (not your files)',
                    onTap: () async {
                      if (!await _confirm('Clear cache?', 'This clears download history only — your downloaded files are untouched.')) return;
                      await provider.clearCache();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cache cleared')));
                    },
                  ),
                  _CleanupTile(
                    icon: Icons.delete_forever_rounded,
                    title: 'Delete all offline materials',
                    subtitle: 'Removes every downloaded file from this device',
                    destructive: true,
                    onTap: () async {
                      if (!await _confirm('Delete all offline materials?',
                          'Every downloaded PDF will be removed from this device. This can\u2019t be undone.')) return;
                      await provider.removeAll();
                      await _load();
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  final StorageSnapshot snapshot;
  const _UsageCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasDeviceStats = snapshot.deviceFreeBytes != null && snapshot.deviceTotalBytes != null;
    final usedFraction = hasDeviceStats
        ? (snapshot.deviceTotalBytes! - snapshot.deviceFreeBytes!) / snapshot.deviceTotalBytes!
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Offline Storage', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 6),
        Text(snapshot.usedFormatted,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        Text('${snapshot.materialCount} PDF${snapshot.materialCount == 1 ? '' : 's'} \u00b7 avg ${snapshot.averageFormatted}',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        if (hasDeviceStats) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usedFraction!.clamp(0, 1),
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Available Device Storage', style: TextStyle(color: Colors.white70, fontSize: 11)),
            Text(snapshot.deviceFreeFormatted!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ],
      ]),
    );
  }
}

class _CourseBreakdown extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final int totalBytes;
  const _CourseBreakdown({required this.entries, required this.totalBytes});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: entries.take(8).map((e) {
        final fraction = totalBytes > 0 ? e.value / totalBytes : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              Text(StorageSnapshot.formatBytes(e.value), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: fraction.clamp(0, 1), minHeight: 5,
                backgroundColor: scheme.primary.withOpacity(0.08),
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary, letterSpacing: 0.5)),
      );
}

class _CleanupTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;
  const _CleanupTile({
    required this.icon, required this.title, required this.subtitle,
    required this.onTap, this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.red : Theme.of(context).colorScheme.primary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: destructive ? Colors.red : null)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      onTap: onTap,
    );
  }
}
