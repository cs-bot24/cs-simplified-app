import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/offline_material.dart';
import '../../providers/offline_provider.dart';
import '../../services/offline/download_queue_manager.dart';

/// Settings → Offline Materials → Download Queue (also reachable from the
/// Offline Library app bar). Shows what's currently downloading, what's
/// waiting/paused, and a short history of completed/failed downloads.
class DownloadQueueScreen extends StatefulWidget {
  const DownloadQueueScreen({super.key});

  @override
  State<DownloadQueueScreen> createState() => _DownloadQueueScreenState();
}

class _DownloadQueueScreenState extends State<DownloadQueueScreen> {
  DownloadQueueSnapshot _snapshot = DownloadQueueSnapshot.empty;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _refresh();
    // The queue has fast-changing fields (bytes received) that don't go
    // through notifyListeners() on every chunk — a light poll while this
    // screen is open keeps the current-download progress bar smooth
    // without flooding the whole app with rebuilds.
    _poller = Timer.periodic(const Duration(milliseconds: 800), (_) => _refresh());
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final snap = await context.read<OfflineProvider>().loadQueueSnapshot();
    if (mounted) setState(() => _snapshot = snap);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OfflineProvider>();
    final s = _snapshot;
    final nothingPending = s.current == null && s.waiting.isEmpty && s.paused.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Download Queue')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (nothingPending && s.completed.isEmpty && s.failed.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Column(children: [
                    Icon(Icons.cloud_done_outlined, size: 56, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('Nothing in the queue', style: TextStyle(color: Colors.grey[500])),
                  ]),
                ),
              ),
            if (s.current != null) ...[
              const _SectionHeader('Current'),
              _QueueTile(
                entry: s.current!,
                trailing: IconButton(
                  icon: const Icon(Icons.pause_circle_outline_rounded),
                  onPressed: () async { await provider.pauseDownload(s.current!.materialId); _refresh(); },
                ),
              ),
            ],
            if (s.waiting.isNotEmpty) ...[
              const _SectionHeader('Waiting'),
              ...s.waiting.map((e) => _QueueTile(
                    entry: e,
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () async { await provider.cancelDownload(e.materialId); _refresh(); },
                    ),
                  )),
            ],
            if (s.paused.isNotEmpty) ...[
              const _SectionHeader('Paused'),
              ...s.paused.map((e) => _QueueTile(
                    entry: e,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        onPressed: () async { await provider.resumeDownload(e.materialId); _refresh(); },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () async { await provider.cancelDownload(e.materialId); _refresh(); },
                      ),
                    ]),
                  )),
            ],
            if (s.failed.isNotEmpty) ...[
              _SectionHeader('Failed', trailing: null),
              ...s.failed.map((e) => _HistoryTile(
                    entry: e,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Retry',
                        onPressed: () async { await provider.retryDownload(e.materialId); _refresh(); },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Remove',
                        onPressed: () async {
                          if (e.id != null) await provider.removeFailedEntry(e.id!);
                          _refresh();
                        },
                      ),
                    ]),
                  )),
            ],
            if (s.completed.isNotEmpty) ...[
              _SectionHeader('Completed', trailing: TextButton(
                onPressed: () async { await provider.clearCompletedDownloads(); _refresh(); },
                child: const Text('Clear Completed', style: TextStyle(fontSize: 12)),
              )),
              ...s.completed.map((e) => _HistoryTile(entry: e, trailing: null)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader(this.title, {this.trailing = const SizedBox.shrink()});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Row(children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary, letterSpacing: 0.5)),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

class _QueueTile extends StatelessWidget {
  final DownloadQueueEntry entry;
  final Widget trailing;
  const _QueueTile({required this.entry, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withOpacity(0.10)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: entry.bytesTotal > 0 ? entry.fraction : null,
                minHeight: 4,
                backgroundColor: scheme.primary.withOpacity(0.08),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              entry.status == QueueEntryStatus.downloading
                  ? '${(entry.fraction * 100).toStringAsFixed(0)}%'
                  : entry.status == QueueEntryStatus.paused ? 'Paused' : 'Waiting\u2026',
              style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
            ),
          ]),
        ),
        trailing,
      ]),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final DownloadHistoryEntry entry;
  final Widget? trailing;
  const _HistoryTile({required this.entry, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        entry.succeeded ? Icons.check_circle_rounded : Icons.error_outline_rounded,
        color: entry.succeeded ? Colors.green : Colors.red,
      ),
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        entry.succeeded ? entry.courseCode ?? '' : (entry.error ?? 'Download failed'),
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
      ),
      trailing: trailing,
    );
  }
}
