import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/fcm_service.dart';
import '../../models/offline_material.dart';
import 'file_integrity_checker.dart';
import 'local_material_repository.dart';
import 'storage_manager.dart';

/// A single item queued for (or currently undergoing) download.
class _QueueItem {
  final int materialId;
  final String title;
  final String fileUrl;
  final int? courseId;
  final String? courseCode;
  final String? categoryName;
  final String fileType;
  int retryCount;

  _QueueItem({
    required this.materialId,
    required this.title,
    required this.fileUrl,
    this.courseId,
    this.courseCode,
    this.categoryName,
    required this.fileType,
    this.retryCount = 0,
  });
}

/// Queues, resumes, retries, and verifies material downloads.
///
/// Responsibilities (per the Offline Materials spec):
///   • Queue downloads, run up to [_maxConcurrent] at once.
///   • Resume interrupted downloads using HTTP Range requests against a
///     partially-written temp file.
///   • Retry failed downloads with capped exponential backoff.
///   • Verify file integrity (via [FileIntegrityChecker]) after every
///     successful download; corrupted files are deleted automatically.
///   • Never download the same file twice — an in-flight or already
///     completed materialId is a no-op.
///   • Respect the user's Wi-Fi-only / Wi-Fi+data preference.
///
/// This class is UI-agnostic — [OfflineProvider] listens to [progressStream]
/// to drive widget state. It's a process-wide singleton so downloads keep
/// running (and get resumed) regardless of which screen is on top.
class DownloadManager {
  DownloadManager({
    LocalMaterialRepository? repository,
    StorageManager? storageManager,
    FileIntegrityChecker? integrityChecker,
    Dio? dio,
  })  : _repo = repository ?? LocalMaterialRepository(),
        _storage = storageManager ?? StorageManager(),
        _integrity = integrityChecker ?? FileIntegrityChecker(),
        _dio = dio ?? Dio();

  static const _maxConcurrent = 2;
  static const _maxRetries = 3;

  final LocalMaterialRepository _repo;
  final StorageManager _storage;
  final FileIntegrityChecker _integrity;
  final Dio _dio;

  final _queue = <_QueueItem>[];
  final _active = <int, CancelToken>{};
  final _lastProgress = <int, DownloadProgress>{};
  final _progressController = StreamController<DownloadProgress>.broadcast();

  /// Broadcast of progress/status changes, keyed by materialId.
  Stream<DownloadProgress> get progressStream => _progressController.stream;

  bool get hasActiveOrQueuedDownloads =>
      _queue.isNotEmpty || _active.isNotEmpty;

  bool isQueuedOrDownloading(int materialId) =>
      _active.containsKey(materialId) ||
      _queue.any((q) => q.materialId == materialId);

  /// Reloads any downloads that were interrupted (app killed mid-download)
  /// from the `download_queue` table and resumes them. Call once at app
  /// startup, after the DB is available.
  Future<void> restorePendingDownloads() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'download_queue',
      where: 'status IN (?, ?)',
      whereArgs: ['queued', 'downloading'],
    );
    for (final r in rows) {
      _queue.add(_QueueItem(
        materialId: r['material_id'] as int,
        title: r['title'] as String,
        fileUrl: r['file_url'] as String,
        courseId: r['course_id'] as int?,
        courseCode: r['course_code'] as String?,
        categoryName: r['category_name'] as String?,
        fileType: (r['file_type'] as String?) ?? 'pdf',
        retryCount: r['retry_count'] as int? ?? 0,
      ));
      _emit(DownloadProgress(materialId: r['material_id'] as int, status: OfflineStatus.queued));
    }
    if (rows.isNotEmpty) {
      dev.log('[DownloadManager] Resumed ${rows.length} pending downloads',
          name: 'DownloadManager');
      unawaited(_pump());
    }
  }

  /// Enqueue a material for download. No-op if it's already downloaded,
  /// queued, or downloading — never download the same file twice.
  Future<void> enqueue({
    required int materialId,
    required String title,
    required String fileUrl,
    int? courseId,
    String? courseCode,
    String? categoryName,
    String fileType = 'pdf',
  }) async {
    final existing = await _repo.getById(materialId);
    if (existing != null && existing.status == OfflineStatus.downloaded) {
      dev.log('[DownloadManager] $materialId already downloaded — skip',
          name: 'DownloadManager');
      return;
    }
    if (isQueuedOrDownloading(materialId)) return;

    final db = await AppDatabase.instance.database;
    await db.insert(
      'download_queue',
      {
        'material_id': materialId,
        'title': title,
        'file_url': fileUrl,
        'course_id': courseId,
        'course_code': courseCode,
        'category_name': categoryName,
        'file_type': fileType,
        'status': 'queued',
        'bytes_received': 0,
        'bytes_total': 0,
        'retry_count': 0,
        'added_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _queue.add(_QueueItem(
      materialId: materialId,
      title: title,
      fileUrl: fileUrl,
      courseId: courseId,
      courseCode: courseCode,
      categoryName: categoryName,
      fileType: fileType,
    ));
    _emit(DownloadProgress(materialId: materialId, status: OfflineStatus.queued));
    unawaited(_pump());
  }

  Future<void> enqueueMany(List<
      ({
        int materialId,
        String title,
        String fileUrl,
        int? courseId,
        String? courseCode,
        String? categoryName,
        String fileType,
      })> items) async {
    for (final it in items) {
      await enqueue(
        materialId: it.materialId,
        title: it.title,
        fileUrl: it.fileUrl,
        courseId: it.courseId,
        courseCode: it.courseCode,
        categoryName: it.categoryName,
        fileType: it.fileType,
      );
    }
  }

  Future<void> cancel(int materialId) async {
    _active[materialId]?.cancel('cancelled_by_user');
    _active.remove(materialId);
    _queue.removeWhere((q) => q.materialId == materialId);
    _lastProgress.remove(materialId);
    final db = await AppDatabase.instance.database;
    await db.delete('download_queue', where: 'material_id = ?', whereArgs: [materialId]);
    _emit(DownloadProgress(materialId: materialId, status: OfflineStatus.notDownloaded));
  }

  /// Pauses an in-flight or queued download. The partially-downloaded temp
  /// file is kept so [resume] can continue it via the Range-based resume
  /// path in [_downloadWithResume].
  Future<void> pause(int materialId) async {
    _active[materialId]?.cancel('paused_by_user');
    _active.remove(materialId);
    _queue.removeWhere((q) => q.materialId == materialId);
    final db = await AppDatabase.instance.database;
    await db.update('download_queue', {'status': 'paused'},
        where: 'material_id = ?', whereArgs: [materialId]);
    _emit(DownloadProgress(materialId: materialId, status: OfflineStatus.paused));
  }

  /// Resumes a paused download, or re-queues a failed one from scratch.
  Future<void> resume(int materialId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('download_queue', where: 'material_id = ?', whereArgs: [materialId]);
    if (rows.isEmpty || isQueuedOrDownloading(materialId)) return;
    final r = rows.first;
    await db.update('download_queue', {'status': 'queued'},
        where: 'material_id = ?', whereArgs: [materialId]);
    _emit(DownloadProgress(materialId: materialId, status: OfflineStatus.queued));
    _queue.add(_QueueItem(
      materialId: materialId,
      title: r['title'] as String,
      fileUrl: r['file_url'] as String,
      courseId: r['course_id'] as int?,
      courseCode: r['course_code'] as String?,
      categoryName: r['category_name'] as String?,
      fileType: (r['file_type'] as String?) ?? 'pdf',
      retryCount: r['retry_count'] as int? ?? 0,
    ));
    unawaited(_pump());
  }

  /// Retries a failed download from scratch (resets the retry counter).
  Future<void> retry(int materialId) async {
    final db = await AppDatabase.instance.database;
    await db.update('download_queue', {'retry_count': 0},
        where: 'material_id = ?', whereArgs: [materialId]);
    await resume(materialId);
  }

  /// Snapshot of everything still pending (queued/downloading/paused) for
  /// the Download Queue screen. Completed/failed history lives separately
  /// in `download_history` — see [LocalMaterialRepository.getHistory].
  Future<List<DownloadQueueEntry>> queueSnapshot() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('download_queue', orderBy: 'added_at ASC');
    return rows.map((r) {
      final materialId = r['material_id'] as int;
      final live = _lastProgress[materialId];
      final status = switch (r['status'] as String) {
        'downloading' => QueueEntryStatus.downloading,
        'paused' => QueueEntryStatus.paused,
        _ => QueueEntryStatus.queued,
      };
      return DownloadQueueEntry(
        materialId: materialId,
        title: r['title'] as String,
        courseCode: r['course_code'] as String?,
        status: status,
        bytesReceived: live?.bytesReceived ?? (r['bytes_received'] as int? ?? 0),
        bytesTotal: live?.bytesTotal ?? (r['bytes_total'] as int? ?? 0),
        retryCount: r['retry_count'] as int? ?? 0,
      );
    }).toList();
  }

  void dispose() => _progressController.close();

  // ── Internals ────────────────────────────────────────────────────────────

  Future<void> _pump() async {
    while (_active.length < _maxConcurrent && _queue.isNotEmpty) {
      final item = _queue.removeAt(0);
      _active[item.materialId] = CancelToken();
      unawaited(_run(item));
    }
  }

  Future<void> _run(_QueueItem item) async {
    // Respect Wi-Fi-only preference.
    if (!await _networkAllowsDownload()) {
      dev.log('[DownloadManager] Wi-Fi required — deferring ${item.materialId}',
          name: 'DownloadManager');
      _active.remove(item.materialId);
      _queue.add(item); // put back; a connectivity listener re-pumps later
      return;
    }

    final db = await AppDatabase.instance.database;
    await db.update('download_queue', {'status': 'downloading'},
        where: 'material_id = ?', whereArgs: [item.materialId]);
    _emit(DownloadProgress(materialId: item.materialId, status: OfflineStatus.downloading));

    final destPath = await _storage.pathFor(item.materialId, item.title, item.fileType);
    final tempPath = '$destPath.part';
    final cancelToken = _active[item.materialId]!;

    try {
      final receivedBytes = await _downloadWithResume(
        url: item.fileUrl,
        tempPath: tempPath,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          _emit(DownloadProgress(
            materialId: item.materialId,
            status: OfflineStatus.downloading,
            bytesReceived: received,
            bytesTotal: total,
          ));
        },
      );

      // Verify integrity: non-empty + hash for future corruption checks.
      final ok = await _integrity.verify(tempPath);
      if (!ok) {
        await File(tempPath).delete().catchError((_) => File(tempPath));
        throw const _DownloadFailure('File failed integrity check after download.');
      }

      final hash = await _integrity.computeSha256(tempPath);
      await File(tempPath).rename(destPath);

      // Merge with any existing record so re-downloading an update never
      // resets reading progress, last-opened page, or favorite status —
      // "Never overwrite user progress."
      final existing = await _repo.getById(item.materialId);
      await _repo.upsert(OfflineMaterial(
        materialId: item.materialId,
        courseId: item.courseId,
        courseCode: item.courseCode,
        categoryName: item.categoryName,
        title: item.title,
        fileUrl: item.fileUrl,
        fileType: item.fileType,
        localPath: destPath,
        fileSizeBytes: receivedBytes,
        fileHash: hash,
        serverVersion: item.fileUrl,
        localVersion: item.fileUrl,
        status: OfflineStatus.downloaded,
        downloadedAt: DateTime.now(),
        lastOpenedAt: existing?.lastOpenedAt,
        lastOpenedPage: existing?.lastOpenedPage ?? 0,
        pageCount: existing?.pageCount,
        readingProgress: existing?.readingProgress ?? 0,
        isFavorite: existing?.isFavorite ?? false,
        // A fresh, successful download always clears any dismissed-update
        // marker — it's now moot.
        ignoredVersion: null,
      ));
      await db.delete('download_queue', where: 'material_id = ?', whereArgs: [item.materialId]);

      _emit(DownloadProgress(materialId: item.materialId, status: OfflineStatus.downloaded));
      unawaited(_repo.addHistory(DownloadHistoryEntry(
        materialId: item.materialId,
        title: item.title,
        courseCode: item.courseCode,
        succeeded: true,
        fileSizeBytes: receivedBytes,
        occurredAt: DateTime.now(),
      )));
      // "User receives notification when completed" — background downloads
      // spec requirement. Best-effort: notification failures never fail
      // the download itself.
      unawaited(FcmService.showDownloadComplete(
        id: 90000 + item.materialId,
        materialTitle: item.title,
      ).catchError((_) {}));
    } on _DownloadFailure catch (e) {
      await _handleFailure(item, db, e.message);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        // Explicit user cancel/pause — already handled in cancel()/pause().
      } else {
        await _handleFailure(item, db, 'Network error: ${e.message}');
      }
    } catch (e) {
      final message = e.toString();
      if (message.toLowerCase().contains('no space')) {
        // Out of disk space — retrying won't help; fail immediately and
        // surface a specific "storage full" notification.
        await _handleFailure(item, db, 'Not enough storage on this device.', forceGiveUp: true);
        unawaited(FcmService.showStorageFull().catchError((_) {}));
      } else {
        await _handleFailure(item, db, message);
      }
    } finally {
      _active.remove(item.materialId);
      unawaited(_pump());
    }
  }

  Future<void> _handleFailure(_QueueItem item, Database db, String reason,
      {bool forceGiveUp = false}) async {
    item.retryCount++;
    if (!forceGiveUp && item.retryCount <= _maxRetries) {
      dev.log(
        '[DownloadManager] retry ${item.retryCount}/$_maxRetries for ${item.materialId}: $reason',
        name: 'DownloadManager',
      );
      await db.update('download_queue', {'status': 'queued', 'retry_count': item.retryCount},
          where: 'material_id = ?', whereArgs: [item.materialId]);
      final backoff = Duration(seconds: 2 * item.retryCount);
      Timer(backoff, () {
        _queue.add(item);
        unawaited(_pump());
      });
    } else {
      dev.log('[DownloadManager] giving up on ${item.materialId}: $reason',
          name: 'DownloadManager');
      await db.update('download_queue', {'status': 'failed'},
          where: 'material_id = ?', whereArgs: [item.materialId]);
      _emit(DownloadProgress(
        materialId: item.materialId,
        status: OfflineStatus.failed,
        error: reason,
      ));
      unawaited(_repo.addHistory(DownloadHistoryEntry(
        materialId: item.materialId,
        title: item.title,
        courseCode: item.courseCode,
        succeeded: false,
        error: reason,
        occurredAt: DateTime.now(),
      )));
      unawaited(FcmService.showDownloadFailed(materialTitle: item.title).catchError((_) {}));
    }
  }

  /// Streams [url] to [tempPath], resuming from the current file length
  /// (if any) via a `Range` request. Returns total bytes written.
  Future<int> _downloadWithResume({
    required String url,
    required String tempPath,
    required CancelToken cancelToken,
    required void Function(int received, int total) onProgress,
  }) async {
    final tempFile = File(tempPath);
    var existingLength = 0;
    if (await tempFile.exists()) {
      existingLength = await tempFile.length();
    } else {
      await tempFile.create(recursive: true);
    }

    final response = await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Accept': 'application/pdf,*/*',
          if (existingLength > 0) 'Range': 'bytes=$existingLength-',
        },
        followRedirects: true,
        receiveTimeout: const Duration(seconds: 120),
      ),
      cancelToken: cancelToken,
    );

    final supportsResume = response.statusCode == 206;
    final startOffset = supportsResume ? existingLength : 0;
    if (!supportsResume && existingLength > 0) {
      // Server ignored Range — restart the file cleanly.
      await tempFile.writeAsBytes([]);
    }

    final contentLength = response.data!.contentLength;
    final total = contentLength > 0 ? contentLength + startOffset : 0;

    final sink = tempFile.openWrite(mode: FileMode.append);
    var received = startOffset;
    try {
      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    return received;
  }

  Future<bool> _networkAllowsDownload() async {
    final pref = await _storage.getNetworkPreference();
    if (pref == DownloadNetworkPreference.wifiAndData) return true;
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  void _emit(DownloadProgress p) {
    _lastProgress[p.materialId] = p;
    if (!_progressController.isClosed) _progressController.add(p);
  }
}

class _DownloadFailure {
  final String message;
  const _DownloadFailure(this.message);
}
