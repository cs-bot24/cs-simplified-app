import 'dart:developer' as dev;
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../models/offline_material.dart';

/// Thin data-access layer over [AppDatabase].
///
/// Owns all SQL for the `offline_materials`, `offline_bookmarks`, and
/// `course_download_prompts` tables. Nothing here knows about Dio, HTTP,
/// or connectivity — this is pure local persistence.
class LocalMaterialRepository {
  Future<Database> get _db async => AppDatabase.instance.database;

  // ── Offline materials ───────────────────────────────────────────────────

  Future<List<OfflineMaterial>> getAll() async {
    final db = await _db;
    final rows = await db.query('offline_materials', orderBy: 'downloaded_at DESC');
    return rows.map(OfflineMaterial.fromRow).toList();
  }

  Future<OfflineMaterial?> getById(int materialId) async {
    final db = await _db;
    final rows = await db.query(
      'offline_materials',
      where: 'material_id = ?',
      whereArgs: [materialId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return OfflineMaterial.fromRow(rows.first);
  }

  Future<List<OfflineMaterial>> getByCourse(int courseId) async {
    final db = await _db;
    final rows = await db.query(
      'offline_materials',
      where: 'course_id = ? AND status = ?',
      whereArgs: [courseId, OfflineStatus.downloaded.name],
    );
    return rows.map(OfflineMaterial.fromRow).toList();
  }

  /// Insert or replace a material's offline record.
  Future<void> upsert(OfflineMaterial material) async {
    final db = await _db;
    await db.insert(
      'offline_materials',
      material.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateStatus(int materialId, OfflineStatus status) async {
    final db = await _db;
    await db.update(
      'offline_materials',
      {'status': status.name},
      where: 'material_id = ?',
      whereArgs: [materialId],
    );
  }

  Future<void> updateReadingProgress(
    int materialId, {
    required int page,
    int? pageCount,
  }) async {
    final db = await _db;
    await db.update(
      'offline_materials',
      {
        'last_opened_page': page,
        'last_opened_at': DateTime.now().toIso8601String(),
        if (pageCount != null) 'page_count': pageCount,
        if (pageCount != null && pageCount > 0)
          'reading_progress': page / pageCount,
      },
      where: 'material_id = ?',
      whereArgs: [materialId],
    );
  }

  Future<void> delete(int materialId) async {
    final db = await _db;
    final existing = await getById(materialId);
    if (existing?.localPath != null) {
      try {
        final f = File(existing!.localPath!);
        if (await f.exists()) await f.delete();
      } catch (e) {
        dev.log('[LocalMaterialRepository] delete file error: $e', name: 'OfflineRepo');
      }
    }
    await db.delete('offline_materials', where: 'material_id = ?', whereArgs: [materialId]);
    await db.delete('offline_bookmarks', where: 'material_id = ?', whereArgs: [materialId]);
  }

  Future<void> deleteMany(List<int> materialIds) async {
    for (final id in materialIds) {
      await delete(id);
    }
  }

  Future<void> deleteAll() async {
    final all = await getAll();
    await deleteMany(all.map((m) => m.materialId).toList());
  }

  /// Drops rows whose backing file no longer exists on disk (deleted via
  /// the OS Files app, storage cleared, etc). Returns the pruned count.
  Future<int> pruneMissingFiles() async {
    final all = await getAll();
    var pruned = 0;
    for (final m in all) {
      if (m.status != OfflineStatus.downloaded) continue;
      if (m.localPath == null || !await File(m.localPath!).exists()) {
        final db = await _db;
        await db.delete('offline_materials', where: 'material_id = ?', whereArgs: [m.materialId]);
        pruned++;
      }
    }
    if (pruned > 0) {
      dev.log('[LocalMaterialRepository] Pruned $pruned stale entries', name: 'OfflineRepo');
    }
    return pruned;
  }

  Future<int> totalStorageBytes() async {
    final all = await getAll();
    return all.fold<int>(0, (sum, m) => sum + m.fileSizeBytes);
  }

  // ── Favorites ────────────────────────────────────────────────────────────

  Future<void> setFavorite(int materialId, bool favorite) async {
    final db = await _db;
    await db.update(
      'offline_materials',
      {'is_favorite': favorite ? 1 : 0},
      where: 'material_id = ?',
      whereArgs: [materialId],
    );
  }

  Future<List<OfflineMaterial>> favorites() async {
    final db = await _db;
    final rows = await db.query(
      'offline_materials',
      where: 'is_favorite = 1 AND status = ?',
      whereArgs: [OfflineStatus.downloaded.name],
    );
    return rows.map(OfflineMaterial.fromRow).toList();
  }

  // ── Update dismissal ("Ignore" on Update Available) ─────────────────────

  Future<void> setIgnoredVersion(int materialId, String? version) async {
    final db = await _db;
    await db.update(
      'offline_materials',
      {'ignored_version': version},
      where: 'material_id = ?',
      whereArgs: [materialId],
    );
  }

  // ── Reading history ──────────────────────────────────────────────────────

  Future<List<OfflineMaterial>> recentlyOpened({int limit = 10}) async {
    final db = await _db;
    final rows = await db.query(
      'offline_materials',
      where: 'last_opened_at IS NOT NULL AND status = ?',
      whereArgs: [OfflineStatus.downloaded.name],
      orderBy: 'last_opened_at DESC',
      limit: limit,
    );
    return rows.map(OfflineMaterial.fromRow).toList();
  }

  // ── Storage analytics ────────────────────────────────────────────────────

  Future<List<OfflineMaterial>> largestFiles({int limit = 5}) async {
    final db = await _db;
    final rows = await db.query(
      'offline_materials',
      where: 'status = ?',
      whereArgs: [OfflineStatus.downloaded.name],
      orderBy: 'file_size_bytes DESC',
      limit: limit,
    );
    return rows.map(OfflineMaterial.fromRow).toList();
  }

  /// Bytes used per course — feeds the storage breakdown graph.
  Future<Map<String, int>> bytesByCourse() async {
    final all = await getAll();
    final map = <String, int>{};
    for (final m in all) {
      if (m.status != OfflineStatus.downloaded) continue;
      final key = m.courseCode ?? 'Other';
      map[key] = (map[key] ?? 0) + m.fileSizeBytes;
    }
    return map;
  }

  Future<List<int>> materialIdsForCourse(int courseId) async {
    final db = await _db;
    final rows = await db.query(
      'offline_materials',
      columns: ['material_id'],
      where: 'course_id = ?',
      whereArgs: [courseId],
    );
    return rows.map((r) => r['material_id'] as int).toList();
  }

  /// Course ids where every downloaded material has 100% reading progress —
  /// feeds the "Delete completed courses" cleanup action.
  Future<List<int>> fullyCompletedCourseIds() async {
    final all = await getAll();
    final byCourse = <int, List<OfflineMaterial>>{};
    for (final m in all) {
      if (m.status != OfflineStatus.downloaded || m.courseId == null) continue;
      byCourse.putIfAbsent(m.courseId!, () => []).add(m);
    }
    return byCourse.entries
        .where((e) => e.value.every((m) => m.readingProgress >= 0.999))
        .map((e) => e.key)
        .toList();
  }

  /// Downloaded materials that have never been opened — feeds "Delete
  /// unused materials".
  Future<List<int>> neverOpenedMaterialIds() async {
    final all = await getAll();
    return all
        .where((m) => m.status == OfflineStatus.downloaded && m.lastOpenedAt == null)
        .map((m) => m.materialId)
        .toList();
  }

  // ── Download history (Completed / Failed sections + "Clear Completed") ──

  Future<void> addHistory(DownloadHistoryEntry entry) async {
    final db = await _db;
    await db.insert('download_history', entry.toRow());
  }

  Future<List<DownloadHistoryEntry>> getHistory({bool? succeeded, int limit = 50}) async {
    final db = await _db;
    final rows = await db.query(
      'download_history',
      where: succeeded == null ? null : 'status = ?',
      whereArgs: succeeded == null ? null : [succeeded ? 'completed' : 'failed'],
      orderBy: 'occurred_at DESC',
      limit: limit,
    );
    return rows.map(DownloadHistoryEntry.fromRow).toList();
  }

  Future<void> clearCompletedHistory() async {
    final db = await _db;
    await db.delete('download_history', where: 'status = ?', whereArgs: ['completed']);
  }

  Future<void> clearHistoryEntry(int id) async {
    final db = await _db;
    await db.delete('download_history', where: 'id = ?', whereArgs: [id]);
  }

  // ── Bookmarks ────────────────────────────────────────────────────────────

  Future<List<OfflineBookmark>> bookmarksFor(int materialId) async {
    final db = await _db;
    final rows = await db.query(
      'offline_bookmarks',
      where: 'material_id = ?',
      whereArgs: [materialId],
      orderBy: 'page ASC',
    );
    return rows.map(OfflineBookmark.fromRow).toList();
  }

  Future<void> addBookmark(OfflineBookmark bookmark) async {
    final db = await _db;
    await db.insert(
      'offline_bookmarks',
      bookmark.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeBookmark(int materialId, int page) async {
    final db = await _db;
    await db.delete(
      'offline_bookmarks',
      where: 'material_id = ? AND page = ?',
      whereArgs: [materialId, page],
    );
  }

  // ── Smart-download prompt tracking ──────────────────────────────────────

  /// Increments the open-count for a course and returns (openCount, already
  /// prompted). Used to decide whether to show the "Download this course
  /// for offline study?" suggestion — shown once only.
  Future<(int, bool)> recordCourseOpen(int courseId) async {
    final db = await _db;
    final rows = await db.query(
      'course_download_prompts',
      where: 'course_id = ?',
      whereArgs: [courseId],
      limit: 1,
    );
    if (rows.isEmpty) {
      await db.insert('course_download_prompts', {
        'course_id': courseId,
        'open_count': 1,
        'prompted': 0,
      });
      return (1, false);
    }
    final openCount = (rows.first['open_count'] as int) + 1;
    final prompted = (rows.first['prompted'] as int) == 1;
    await db.update(
      'course_download_prompts',
      {'open_count': openCount},
      where: 'course_id = ?',
      whereArgs: [courseId],
    );
    return (openCount, prompted);
  }

  Future<void> markCoursePrompted(int courseId) async {
    final db = await _db;
    await db.update(
      'course_download_prompts',
      {'prompted': 1},
      where: 'course_id = ?',
      whereArgs: [courseId],
    );
  }
}
