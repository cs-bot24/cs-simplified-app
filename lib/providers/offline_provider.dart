import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';

import '../models/material_model.dart';
import '../models/offline_material.dart';
import '../services/offline/download_queue_manager.dart';
import '../services/offline/offline_library_service.dart';
import '../services/offline/offline_material_service.dart';
import '../services/offline/storage_analytics.dart';
import '../services/offline/storage_manager.dart';

/// UI-facing state for the Offline Materials System.
///
/// Thin by design — all real logic lives in [OfflineMaterialService] and
/// the services it composes. This class exists to:
///   • Hold an in-memory, notifyListeners()-driven cache of offline status
///     per materialId (so MaterialCard etc. rebuild instantly on downloads).
///   • Translate [DownloadManager] progress events into UI-friendly state.
///   • Give screens (MaterialCard, OfflineScreen, course screens, settings)
///     a single Provider to depend on.
class OfflineProvider extends ChangeNotifier {
  final OfflineMaterialService _service = OfflineMaterialService.instance;
  final OfflineLibraryService _library = OfflineLibraryService.instance;

  final Map<int, OfflineMaterial> _byId = {};
  final Map<int, DownloadProgress> _progress = {};
  StreamSubscription<DownloadProgress>? _progressSub;

  List<OfflineMaterial> get materials =>
      List.unmodifiable(_byId.values.toList()..sort((a, b) {
        final ad = a.downloadedAt ?? DateTime(1970);
        final bd = b.downloadedAt ?? DateTime(1970);
        return bd.compareTo(ad);
      }));

  int get count => _byId.values.where((m) => m.isDownloaded).length;

  // ── Initialisation ─────────────────────────────────────────────────────────

  /// Call once on app start (mirrors the old provider's contract).
  Future<void> loadFromStorage() async {
    await _service.initialize();
    final all = await _service.getAllDownloaded();
    _byId
      ..clear()
      ..addEntries(all.map((m) => MapEntry(m.materialId, m)));
    notifyListeners();

    _progressSub?.cancel();
    _progressSub = _service.downloadManager.progressStream.listen(_onProgress);
  }

  void _onProgress(DownloadProgress p) {
    _progress[p.materialId] = p;
    if (p.status == OfflineStatus.downloaded || p.status == OfflineStatus.failed) {
      // Refresh the persisted row once a download settles.
      unawaited(_service.statusFor(p.materialId).then((m) {
        if (m != null) {
          _byId[p.materialId] = m;
        } else if (p.status == OfflineStatus.failed) {
          _byId.remove(p.materialId);
        }
        notifyListeners();
      }));
    } else {
      notifyListeners();
    }
  }

  // ── Status lookups ───────────────────────────────────────────────────────

  OfflineStatus statusOf(int materialId) {
    final live = _progress[materialId];
    if (live != null &&
        (live.status == OfflineStatus.downloading ||
            live.status == OfflineStatus.queued ||
            live.status == OfflineStatus.paused)) {
      return live.status;
    }
    return _byId[materialId]?.status ?? OfflineStatus.notDownloaded;
  }

  bool isDownloaded(int materialId) => statusOf(materialId) == OfflineStatus.downloaded;

  bool hasUpdate(int materialId) => statusOf(materialId) == OfflineStatus.updateAvailable;

  /// Download progress in [0, 1] for a material currently downloading.
  double progressOf(int materialId) => _progress[materialId]?.fraction ?? 0;

  int downloadedCountForCourse(int courseId) =>
      _byId.values.where((m) => m.courseId == courseId && m.isDownloaded).length;

  OfflineMaterial? materialFor(int materialId) => _byId[materialId];

  /// Total bytes used by all downloaded materials, formatted for display.
  String get totalStorageUsed {
    final total = _byId.values.fold<int>(0, (sum, m) => sum + m.fileSizeBytes);
    if (total == 0) return '0 KB';
    if (total < 1024 * 1024) return '${(total / 1024).toStringAsFixed(0)} KB';
    return '${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Downloads ────────────────────────────────────────────────────────────

  Future<void> download(MaterialModel material) async {
    // Optimistic UI state so the card flips to "queued" immediately.
    _progress[material.id] =
        DownloadProgress(materialId: material.id, status: OfflineStatus.queued);
    notifyListeners();
    try {
      await _service.download(material);
    } catch (e) {
      dev.log('[OfflineProvider] download error: $e', name: 'OfflineProvider');
    }
  }

  Future<void> downloadCourse(List<MaterialModel> materials) => _service.downloadCourse(materials);

  Future<void> cancelDownload(int materialId) async {
    await _service.cancelDownload(materialId);
    _progress.remove(materialId);
    notifyListeners();
  }

  Future<void> update(MaterialModel material) => download(material);

  Future<void> keepCurrentVersion(int materialId) async {
    await _service.keepCurrentVersion(materialId);
    final m = await _service.statusFor(materialId);
    if (m != null) _byId[materialId] = m;
    notifyListeners();
  }

  // ── Delete ───────────────────────────────────────────────────────────────

  Future<void> remove(int materialId) async {
    await _service.delete(materialId);
    _byId.remove(materialId);
    _progress.remove(materialId);
    notifyListeners();
  }

  Future<void> removeMany(List<int> materialIds) async {
    await _service.deleteMany(materialIds);
    for (final id in materialIds) {
      _byId.remove(id);
      _progress.remove(id);
    }
    notifyListeners();
  }

  Future<void> removeAll() async {
    await _service.deleteAll();
    _byId.clear();
    _progress.clear();
    notifyListeners();
  }

  // ── Opening (local-first) ───────────────────────────────────────────────

  /// Returns a verified local file path with zero network contact, or null
  /// if there's no usable offline copy (caller should fall back to the
  /// online viewer).
  Future<String?> resolveLocalPath(int materialId) => _service.resolveLocalPath(materialId);

  Future<void> recordProgress(int materialId, {required int page, int? pageCount}) =>
      _service.recordProgress(materialId, page: page, pageCount: pageCount);

  // ── Sync ─────────────────────────────────────────────────────────────────

  Future<int> checkForUpdates() async {
    final updated = await _service.checkForUpdates();
    if (updated > 0) {
      final all = await _service.getAllDownloaded();
      _byId
        ..clear()
        ..addEntries(all.map((m) => MapEntry(m.materialId, m)));
      notifyListeners();
    }
    return updated;
  }

  // ── Settings ─────────────────────────────────────────────────────────────

  Future<DownloadNetworkPreference> getNetworkPreference() => _service.storage.getNetworkPreference();
  Future<void> setNetworkPreference(DownloadNetworkPreference pref) =>
      _service.storage.setNetworkPreference(pref);

  Future<AutoCleanupPolicy> getCleanupPolicy() => _service.storage.getCleanupPolicy();
  Future<void> setCleanupPolicy(AutoCleanupPolicy policy) =>
      _service.storage.setCleanupPolicy(policy);

  // ── Smart download suggestion ───────────────────────────────────────────

  Future<bool> shouldSuggestCourseDownload(int courseId) =>
      _service.shouldSuggestCourseDownload(courseId);

  // ── Favorites (Phase 2) ──────────────────────────────────────────────────

  Future<void> toggleFavorite(int materialId) async {
    final current = _byId[materialId];
    if (current == null) return;
    final next = !current.isFavorite;
    _byId[materialId] = current.copyWith(isFavorite: next);
    notifyListeners();
    await _library.setFavorite(materialId, next);
  }

  List<OfflineMaterial> get favorites =>
      _byId.values.where((m) => m.isFavorite && m.isDownloaded).toList();

  // ── Recently opened (Phase 2) ────────────────────────────────────────────

  /// Pulled straight from the in-memory cache — no I/O, so it's safe to
  /// call from build().
  List<OfflineMaterial> recentlyOpened({int limit = 10}) {
    final list = _byId.values.where((m) => m.lastOpenedAt != null).toList()
      ..sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));
    return list.take(limit).toList();
  }

  // ── Search / filter / sort (Phase 2, Offline Library screen) ───────────

  List<OfflineMaterial> search(String query) => _library.search(materials, query);
  List<OfflineMaterial> filterBy(List<OfflineMaterial> list, LibraryFilter filter) =>
      _library.filter(list, filter);
  List<OfflineMaterial> sortBy(List<OfflineMaterial> list, LibrarySort sortOption) =>
      _library.sort(list, sortOption);

  // ── Update dismissal (Ignore / Later / Update) ──────────────────────────

  Future<void> ignoreUpdate(int materialId) async {
    final m = _byId[materialId];
    if (m == null) return;
    await _library.ignoreUpdate(m);
    _byId[materialId] = m.copyWith(ignoredVersion: m.serverVersion);
    notifyListeners();
  }

  Future<void> applyUpdate(int materialId) async {
    final m = _byId[materialId];
    if (m == null) return;
    await _library.applyUpdate(m);
  }

  // ── Download Queue screen ───────────────────────────────────────────────

  Future<DownloadQueueSnapshot> loadQueueSnapshot() => _library.queue.snapshot();
  Future<void> pauseDownload(int materialId) => _library.queue.pause(materialId);
  Future<void> resumeDownload(int materialId) => _library.queue.resume(materialId);
  Future<void> retryDownload(int materialId) => _library.queue.retry(materialId);
  Future<void> removeFailedEntry(int historyId) => _library.queue.removeFailedEntry(historyId);
  Future<void> clearCompletedDownloads() => _library.queue.clearCompleted();

  // ── Storage Management screen ───────────────────────────────────────────

  Future<StorageSnapshot> loadStorageSnapshot() => _library.storageAnalytics.snapshot();

  Future<int> deleteCompletedCourses() async {
    final n = await _library.deleteCompletedCourses();
    await _refreshAll();
    return n;
  }

  Future<int> deleteUnusedMaterials() async {
    final n = await _library.deleteUnusedMaterials();
    await _refreshAll();
    return n;
  }

  Future<int> deleteOldDownloads({int days = 60}) async {
    final n = await _library.deleteOldDownloads(days: days);
    await _refreshAll();
    return n;
  }

  Future<void> clearCache() => _library.clearCache();

  Future<void> _refreshAll() async {
    final all = await _service.getAllDownloaded();
    _byId
      ..clear()
      ..addEntries(all.map((m) => MapEntry(m.materialId, m)));
    notifyListeners();
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }
}
