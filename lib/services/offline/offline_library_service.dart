import '../../models/material_model.dart';
import '../../models/offline_material.dart';
import 'download_queue_manager.dart';
import 'local_material_repository.dart';
import 'offline_material_service.dart';
import 'reading_history_repository.dart';
import 'storage_analytics.dart';

enum LibraryFilter {
  all,
  recentlyOpened,
  recentlyDownloaded,
  completed,
  unread,
  favorites,
  largeFiles,
}

enum LibrarySort {
  recentlyOpened,
  recentlyDownloaded,
  courseName,
  courseCode,
  fileSize,
  readingProgress,
  alphabetical,
}

/// A file counts as "large" for the Large Files filter above this size.
const kLargeFileBytes = 20 * 1024 * 1024; // 20 MB

/// Facade for the Offline Library screen (Phase 2): search/filter/sort over
/// downloaded materials, favorites, per-version update dismissal, and bulk
/// storage cleanup actions.
///
/// Composes rather than duplicates: [OfflineMaterialService] (Phase 1)
/// still owns download/open/delete; this adds the Library-specific layer
/// on top so Phase 1 call sites (MaterialCard, PdfViewerScreen, course
/// screens) are untouched.
class OfflineLibraryService {
  OfflineLibraryService._internal()
      : materials = OfflineMaterialService.instance,
        repository = OfflineMaterialService.instance.repository,
        storageAnalytics = StorageAnalytics(repository: OfflineMaterialService.instance.repository),
        readingHistory = ReadingHistoryRepository(repository: OfflineMaterialService.instance.repository),
        queue = DownloadQueueManager(
          downloadManager: OfflineMaterialService.instance.downloadManager,
          repository: OfflineMaterialService.instance.repository,
        );

  static final OfflineLibraryService instance = OfflineLibraryService._internal();

  final OfflineMaterialService materials;
  final LocalMaterialRepository repository;
  final StorageAnalytics storageAnalytics;
  final ReadingHistoryRepository readingHistory;
  final DownloadQueueManager queue;

  // ── Favorites ────────────────────────────────────────────────────────────

  Future<void> setFavorite(int materialId, bool favorite) => repository.setFavorite(materialId, favorite);

  // ── Update dismissal ─────────────────────────────────────────────────────

  /// "Ignore" — never prompt again for this exact server version. A future
  /// re-upload (new version) will surface again regardless.
  Future<void> ignoreUpdate(OfflineMaterial material) =>
      repository.setIgnoredVersion(material.materialId, material.serverVersion);

  /// "Update" — re-download the new version now. Reading progress is
  /// preserved: the downloaded row's `last_opened_page`/`reading_progress`
  /// aren't touched by a re-download (see `DownloadManager._run`), only
  /// the file itself and its version stamp change.
  Future<void> applyUpdate(OfflineMaterial m) => materials.download(MaterialModel(
        id: m.materialId,
        courseId: m.courseId ?? 0,
        categoryId: 0,
        materialTitle: m.title,
        fileUrl: m.serverVersion ?? m.fileUrl,
        fileType: m.fileType,
        isVisible: true,
        uploadedAt: '',
        courseCode: m.courseCode,
        categoryName: m.categoryName,
      ));

  // ── Cleanup actions (Storage Management screen) ─────────────────────────

  Future<int> deleteCompletedCourses() async {
    final courseIds = await repository.fullyCompletedCourseIds();
    var removed = 0;
    for (final id in courseIds) {
      final materialIds = await repository.materialIdsForCourse(id);
      await repository.deleteMany(materialIds);
      removed += materialIds.length;
    }
    return removed;
  }

  Future<int> deleteUnusedMaterials() async {
    final ids = await repository.neverOpenedMaterialIds();
    await repository.deleteMany(ids);
    return ids.length;
  }

  /// "Delete old downloads" — anything not opened in the last [days] days
  /// (defaults to a 60-day horizon; distinct from the user's configurable
  /// Auto Cleanup policy in Offline Settings, which runs automatically).
  Future<int> deleteOldDownloads({int days = 60}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final all = await repository.getAll();
    final stale = all
        .where((m) => m.isDownloaded)
        .where((m) => (m.lastOpenedAt ?? m.downloadedAt ?? DateTime.now()).isBefore(cutoff))
        .map((m) => m.materialId)
        .toList();
    await repository.deleteMany(stale);
    return stale.length;
  }

  Future<void> deleteAll() => repository.deleteAll();

  /// Clears completed-download history entries (not the files themselves).
  Future<void> clearCache() => queue.clearCompleted();

  // ── Search / filter / sort (pure, in-memory — fast at library scale) ────

  List<OfflineMaterial> search(List<OfflineMaterial> materials, String query) {
    if (query.trim().isEmpty) return materials;
    final q = query.toLowerCase();
    return materials.where((m) {
      return m.title.toLowerCase().contains(q) ||
          (m.courseCode?.toLowerCase().contains(q) ?? false) ||
          (m.categoryName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<OfflineMaterial> filter(List<OfflineMaterial> materials, LibraryFilter filter) {
    switch (filter) {
      case LibraryFilter.all:
        return materials;
      case LibraryFilter.recentlyOpened:
        return materials.where((m) => m.lastOpenedAt != null).toList();
      case LibraryFilter.recentlyDownloaded:
        return materials.where((m) => m.downloadedAt != null).toList();
      case LibraryFilter.completed:
        return materials.where((m) => m.readingProgress >= 0.999).toList();
      case LibraryFilter.unread:
        return materials.where((m) => m.lastOpenedAt == null).toList();
      case LibraryFilter.favorites:
        return materials.where((m) => m.isFavorite).toList();
      case LibraryFilter.largeFiles:
        return materials.where((m) => m.fileSizeBytes >= kLargeFileBytes).toList();
    }
  }

  List<OfflineMaterial> sort(List<OfflineMaterial> materials, LibrarySort sort) {
    final list = [...materials];
    int cmp(OfflineMaterial a, OfflineMaterial b) {
      switch (sort) {
        case LibrarySort.recentlyOpened:
          return (b.lastOpenedAt ?? DateTime(1970)).compareTo(a.lastOpenedAt ?? DateTime(1970));
        case LibrarySort.recentlyDownloaded:
          return (b.downloadedAt ?? DateTime(1970)).compareTo(a.downloadedAt ?? DateTime(1970));
        case LibrarySort.courseName:
          return (a.categoryName ?? '').compareTo(b.categoryName ?? '');
        case LibrarySort.courseCode:
          return (a.courseCode ?? '').compareTo(b.courseCode ?? '');
        case LibrarySort.fileSize:
          return b.fileSizeBytes.compareTo(a.fileSizeBytes);
        case LibrarySort.readingProgress:
          return b.readingProgress.compareTo(a.readingProgress);
        case LibrarySort.alphabetical:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    }

    // "Favorites appear first" regardless of sort — combined into a single
    // comparator (List.sort isn't stable, so two sequential sorts would
    // scramble the secondary ordering within each favorite group).
    list.sort((a, b) {
      final fav = (b.isFavorite ? 1 : 0) - (a.isFavorite ? 1 : 0);
      return fav != 0 ? fav : cmp(a, b);
    });
    return list;
  }
}
