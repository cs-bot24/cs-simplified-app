import '../../models/offline_material.dart';
import 'download_manager.dart';
import 'local_material_repository.dart';

/// A point-in-time view of the download queue, grouped the way the
/// Download Queue screen presents it.
class DownloadQueueSnapshot {
  final DownloadQueueEntry? current;
  final List<DownloadQueueEntry> waiting;
  final List<DownloadQueueEntry> paused;
  final List<DownloadHistoryEntry> completed;
  final List<DownloadHistoryEntry> failed;

  const DownloadQueueSnapshot({
    this.current,
    this.waiting = const [],
    this.paused = const [],
    this.completed = const [],
    this.failed = const [],
  });

  static const empty = DownloadQueueSnapshot();
}

/// Everything the Download Queue screen needs: current transfer, waiting
/// list, paused list, and completed/failed history — plus the actions
/// (pause/resume/retry/cancel/remove/clear completed).
///
/// Thin by design — [DownloadManager] owns the actual transfer state,
/// this just shapes it for display and adds the history-backed sections
/// DownloadManager doesn't track itself.
class DownloadQueueManager {
  DownloadQueueManager({
    required DownloadManager downloadManager,
    LocalMaterialRepository? repository,
  })  : _downloads = downloadManager,
        _repo = repository ?? LocalMaterialRepository();

  final DownloadManager _downloads;
  final LocalMaterialRepository _repo;

  Future<DownloadQueueSnapshot> snapshot() async {
    final entries = await _downloads.queueSnapshot();
    final current = entries.where((e) => e.status == QueueEntryStatus.downloading);
    final waiting = entries.where((e) => e.status == QueueEntryStatus.queued).toList();
    final paused = entries.where((e) => e.status == QueueEntryStatus.paused).toList();
    final completed = await _repo.getHistory(succeeded: true, limit: 30);
    final failed = await _repo.getHistory(succeeded: false, limit: 30);
    return DownloadQueueSnapshot(
      current: current.isEmpty ? null : current.first,
      waiting: waiting,
      paused: paused,
      completed: completed,
      failed: failed,
    );
  }

  Future<void> pause(int materialId) => _downloads.pause(materialId);
  Future<void> resume(int materialId) => _downloads.resume(materialId);
  Future<void> retry(int materialId) => _downloads.retry(materialId);
  Future<void> cancel(int materialId) => _downloads.cancel(materialId);

  /// "Remove" a failed entry from the Failed section (distinct from retry).
  Future<void> removeFailedEntry(int historyId) => _repo.clearHistoryEntry(historyId);

  Future<void> clearCompleted() => _repo.clearCompletedHistory();
}
