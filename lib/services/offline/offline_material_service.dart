import 'dart:async';
import 'dart:developer' as dev;

import '../../models/offline_material.dart';
import '../../models/material_model.dart';
import 'download_manager.dart';
import 'file_integrity_checker.dart';
import 'local_material_repository.dart';
import 'offline_sync_service.dart';
import 'storage_manager.dart';

/// Single entry point the rest of the app uses for everything offline.
///
/// This is the only offline class most UI code should ever import
/// directly (via `OfflineProvider`, its `ChangeNotifier` wrapper).
/// It composes:
///   • [LocalMaterialRepository] — persistence
///   • [DownloadManager]         — queueing/resume/retry
///   • [OfflineSyncService]      — update checking
///   • [StorageManager]          — filesystem + settings
///   • [FileIntegrityChecker]    — corruption detection
///
/// Kept as an app-wide singleton so downloads and sync survive navigation
/// and screen disposal.
class OfflineMaterialService {
  OfflineMaterialService._internal()
      : repository = LocalMaterialRepository(),
        storage = StorageManager(),
        integrity = FileIntegrityChecker(),
        sync = OfflineSyncService() {
    downloadManager = DownloadManager(
      repository: repository,
      storageManager: storage,
      integrityChecker: integrity,
    );
  }

  static final OfflineMaterialService instance = OfflineMaterialService._internal();

  final LocalMaterialRepository repository;
  final StorageManager storage;
  final FileIntegrityChecker integrity;
  final OfflineSyncService sync;
  late final DownloadManager downloadManager;

  bool _initialized = false;

  /// Call once at app startup (after Firebase/storage init, before the
  /// first screen that shows a MaterialCard/OfflineScreen).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final pruned = await repository.pruneMissingFiles();
    if (pruned > 0) {
      dev.log('[OfflineMaterialService] pruned $pruned missing files', name: 'OfflineService');
    }
    await downloadManager.restorePendingDownloads();
    sync.startAutoSync();
    unawaited(runAutoCleanup());
  }

  // ── Query ────────────────────────────────────────────────────────────────

  Future<List<OfflineMaterial>> getAllDownloaded() => repository.getAll();

  Future<OfflineMaterial?> statusFor(int materialId) => repository.getById(materialId);

  bool isQueuedOrDownloading(int materialId) =>
      downloadManager.isQueuedOrDownloading(materialId);

  // ── Download ─────────────────────────────────────────────────────────────

  Future<void> download(MaterialModel material) => downloadManager.enqueue(
        materialId: material.id,
        title: material.materialTitle,
        fileUrl: material.fileUrl,
        courseId: material.courseId,
        courseCode: material.courseCode,
        categoryName: material.categoryName,
        fileType: material.fileType,
      );

  /// "Download Entire Course" — queues every material at once; the
  /// [DownloadManager] handles concurrency/order internally.
  Future<void> downloadCourse(List<MaterialModel> materials) async {
    for (final m in materials) {
      await download(m);
    }
  }

  Future<void> cancelDownload(int materialId) => downloadManager.cancel(materialId);

  Future<void> update(MaterialModel material) => download(material);

  Future<void> keepCurrentVersion(int materialId) async {
    final m = await repository.getById(materialId);
    if (m != null) {
      await repository.upsert(m.copyWith(status: OfflineStatus.downloaded));
    }
  }

  // ── Delete ───────────────────────────────────────────────────────────────

  Future<void> delete(int materialId) => repository.delete(materialId);
  Future<void> deleteMany(List<int> materialIds) => repository.deleteMany(materialIds);
  Future<void> deleteAll() => repository.deleteAll();

  // ── Opening (the core offline-first rule) ───────────────────────────────

  /// Returns the local file path to open, WITHOUT any network/backend
  /// contact, if-and-only-if a verified local copy exists. Also stamps
  /// last-opened-at. Returns null if there is no usable local copy —
  /// callers should fall back to the online viewer in that case.
  Future<String?> resolveLocalPath(int materialId) async {
    final m = await repository.getById(materialId);
    if (m == null || m.localPath == null) return null;
    if (m.status != OfflineStatus.downloaded && m.status != OfflineStatus.updateAvailable) {
      return null;
    }
    final ok = await integrity.verify(m.localPath!); // existence + non-empty only (fast path)
    if (!ok) {
      // Corrupted or missing — clean up and signal "not available offline".
      await repository.delete(materialId);
      return null;
    }
    return m.localPath;
  }

  Future<void> recordProgress(int materialId, {required int page, int? pageCount}) =>
      repository.updateReadingProgress(materialId, page: page, pageCount: pageCount);

  // ── Sync ─────────────────────────────────────────────────────────────────

  Future<int> checkForUpdates() => sync.checkForUpdates();

  // ── Storage / cleanup ────────────────────────────────────────────────────

  Future<int> totalStorageBytes() => repository.totalStorageBytes();

  Future<void> runAutoCleanup() async {
    final policy = await storage.getCleanupPolicy();
    final days = policy.days;
    if (days == null) return;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final all = await repository.getAll();
    final stale = all.where((m) {
      final reference = m.lastOpenedAt ?? m.downloadedAt;
      return reference != null && reference.isBefore(cutoff);
    }).map((m) => m.materialId).toList();
    if (stale.isNotEmpty) {
      dev.log('[OfflineMaterialService] auto-cleanup removing ${stale.length} materials',
          name: 'OfflineService');
      await repository.deleteMany(stale);
    }
  }

  // ── Smart download suggestion ───────────────────────────────────────────

  /// Returns true exactly once per course — the first time a course has
  /// been opened enough times to warrant suggesting a bulk download, and
  /// only if it hasn't been suggested before.
  Future<bool> shouldSuggestCourseDownload(int courseId, {int threshold = 3}) async {
    final (openCount, alreadyPrompted) = await repository.recordCourseOpen(courseId);
    if (alreadyPrompted) return false;
    if (openCount < threshold) return false;
    await repository.markCoursePrompted(courseId);
    return true;
  }

  void dispose() {
    downloadManager.dispose();
    sync.dispose();
  }
}
