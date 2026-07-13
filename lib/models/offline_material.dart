/// Lifecycle state of a material with respect to offline availability.
///
/// Mirrors the four PDF-card states from the Offline Materials spec:
///   notDownloaded → downloading → downloaded → (updateAvailable)
enum OfflineStatus {
  notDownloaded,
  queued,
  downloading,
  paused,
  downloaded,
  updateAvailable,
  failed,
}

/// A material that has been downloaded (or is in the process of being
/// downloaded) for offline use.
///
/// This is the persisted row shape for the `offline_materials` table.
/// Unlike the old model, the file is *never* re-validated with
/// `File.existsSync()` on every read — `LocalMaterialRepository` handles
/// pruning stale rows explicitly, so this object stays a cheap, synchronous
/// data holder.
class OfflineMaterial {
  final int materialId;
  final int? courseId;
  final String? courseCode;
  final String? categoryName;
  final String title;
  final String fileUrl;
  final String fileType;
  final String? localPath;
  final int fileSizeBytes;
  final String? fileHash;
  final String? serverVersion;
  final String? localVersion;
  final OfflineStatus status;
  final DateTime? downloadedAt;
  final DateTime? lastOpenedAt;
  final int lastOpenedPage;
  final int? pageCount;
  final double readingProgress;
  final bool isFavorite;
  final String? ignoredVersion;

  const OfflineMaterial({
    required this.materialId,
    this.courseId,
    this.courseCode,
    this.categoryName,
    required this.title,
    required this.fileUrl,
    this.fileType = 'pdf',
    this.localPath,
    this.fileSizeBytes = 0,
    this.fileHash,
    this.serverVersion,
    this.localVersion,
    this.status = OfflineStatus.notDownloaded,
    this.downloadedAt,
    this.lastOpenedAt,
    this.lastOpenedPage = 0,
    this.pageCount,
    this.readingProgress = 0,
    this.isFavorite = false,
    this.ignoredVersion,
  });

  bool get isDownloaded => status == OfflineStatus.downloaded;
  bool get hasUpdate => status == OfflineStatus.updateAvailable;

  /// True only if there's an update AND the user hasn't already dismissed
  /// this exact version via "Ignore" (see `OfflineLibraryService.ignoreUpdate`).
  bool get hasUnignoredUpdate =>
      hasUpdate && (ignoredVersion == null || ignoredVersion != serverVersion);

  /// Human-readable file size: "238 KB", "1.4 MB", etc.
  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// How long ago this was downloaded — "Just now", "2h ago", "Yesterday", etc.
  String get timeAgo {
    if (downloadedAt == null) return '';
    final diff = DateTime.now().difference(downloadedAt!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  OfflineMaterial copyWith({
    int? courseId,
    String? courseCode,
    String? categoryName,
    String? title,
    String? fileUrl,
    String? fileType,
    String? localPath,
    int? fileSizeBytes,
    String? fileHash,
    String? serverVersion,
    String? localVersion,
    OfflineStatus? status,
    DateTime? downloadedAt,
    DateTime? lastOpenedAt,
    int? lastOpenedPage,
    int? pageCount,
    double? readingProgress,
    bool? isFavorite,
    String? ignoredVersion,
  }) => OfflineMaterial(
        materialId: materialId,
        courseId: courseId ?? this.courseId,
        courseCode: courseCode ?? this.courseCode,
        categoryName: categoryName ?? this.categoryName,
        title: title ?? this.title,
        fileUrl: fileUrl ?? this.fileUrl,
        fileType: fileType ?? this.fileType,
        localPath: localPath ?? this.localPath,
        fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
        fileHash: fileHash ?? this.fileHash,
        serverVersion: serverVersion ?? this.serverVersion,
        localVersion: localVersion ?? this.localVersion,
        status: status ?? this.status,
        downloadedAt: downloadedAt ?? this.downloadedAt,
        lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
        lastOpenedPage: lastOpenedPage ?? this.lastOpenedPage,
        pageCount: pageCount ?? this.pageCount,
        readingProgress: readingProgress ?? this.readingProgress,
        isFavorite: isFavorite ?? this.isFavorite,
        ignoredVersion: ignoredVersion ?? this.ignoredVersion,
      );

  Map<String, dynamic> toRow() => {
        'material_id': materialId,
        'course_id': courseId,
        'course_code': courseCode,
        'category_name': categoryName,
        'title': title,
        'file_url': fileUrl,
        'file_type': fileType,
        'local_path': localPath,
        'file_size_bytes': fileSizeBytes,
        'file_hash': fileHash,
        'server_version': serverVersion,
        'local_version': localVersion,
        'status': status.name,
        'downloaded_at': downloadedAt?.toIso8601String(),
        'last_opened_at': lastOpenedAt?.toIso8601String(),
        'last_opened_page': lastOpenedPage,
        'page_count': pageCount,
        'reading_progress': readingProgress,
        'is_favorite': isFavorite ? 1 : 0,
        'ignored_version': ignoredVersion,
      };

  factory OfflineMaterial.fromRow(Map<String, dynamic> r) => OfflineMaterial(
        materialId: r['material_id'] as int,
        courseId: r['course_id'] as int?,
        courseCode: r['course_code'] as String?,
        categoryName: r['category_name'] as String?,
        title: r['title'] as String,
        fileUrl: r['file_url'] as String,
        fileType: (r['file_type'] as String?) ?? 'pdf',
        localPath: r['local_path'] as String?,
        fileSizeBytes: (r['file_size_bytes'] as int?) ?? 0,
        fileHash: r['file_hash'] as String?,
        serverVersion: r['server_version'] as String?,
        localVersion: r['local_version'] as String?,
        status: OfflineStatus.values.firstWhere(
          (s) => s.name == r['status'],
          orElse: () => OfflineStatus.notDownloaded,
        ),
        downloadedAt: r['downloaded_at'] != null
            ? DateTime.tryParse(r['downloaded_at'] as String)
            : null,
        lastOpenedAt: r['last_opened_at'] != null
            ? DateTime.tryParse(r['last_opened_at'] as String)
            : null,
        lastOpenedPage: (r['last_opened_page'] as int?) ?? 0,
        pageCount: r['page_count'] as int?,
        readingProgress: (r['reading_progress'] as num?)?.toDouble() ?? 0,
        isFavorite: ((r['is_favorite'] as int?) ?? 0) == 1,
        ignoredVersion: r['ignored_version'] as String?,
      );
}

/// A bookmark saved against a material, valid offline.
class OfflineBookmark {
  final int? id;
  final int materialId;
  final int page;
  final String? label;
  final DateTime createdAt;

  const OfflineBookmark({
    this.id,
    required this.materialId,
    required this.page,
    this.label,
    required this.createdAt,
  });

  Map<String, dynamic> toRow() => {
        if (id != null) 'id': id,
        'material_id': materialId,
        'page': page,
        'label': label,
        'created_at': createdAt.toIso8601String(),
      };

  factory OfflineBookmark.fromRow(Map<String, dynamic> r) => OfflineBookmark(
        id: r['id'] as int?,
        materialId: r['material_id'] as int,
        page: r['page'] as int,
        label: r['label'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String),
      );
}

/// Live state for a download in progress — held in memory by
/// [DownloadManager] and broadcast via its progress stream.
class DownloadProgress {
  final int materialId;
  final OfflineStatus status;
  final int bytesReceived;
  final int bytesTotal;
  final String? error;

  const DownloadProgress({
    required this.materialId,
    required this.status,
    this.bytesReceived = 0,
    this.bytesTotal = 0,
    this.error,
  });

  double get fraction => bytesTotal > 0 ? bytesReceived / bytesTotal : 0;
  int get percent => (fraction * 100).round();
}

/// Status of a single row in the live download queue (pending work only —
/// completed/failed history lives in [DownloadHistoryEntry]).
enum QueueEntryStatus { queued, downloading, paused }

/// One row of the Download Queue screen's "Current" / "Waiting" sections.
class DownloadQueueEntry {
  final int materialId;
  final String title;
  final String? courseCode;
  final QueueEntryStatus status;
  final int bytesReceived;
  final int bytesTotal;
  final int retryCount;

  const DownloadQueueEntry({
    required this.materialId,
    required this.title,
    this.courseCode,
    required this.status,
    this.bytesReceived = 0,
    this.bytesTotal = 0,
    this.retryCount = 0,
  });

  double get fraction => bytesTotal > 0 ? bytesReceived / bytesTotal : 0;
}

/// A completed or failed download, logged so the Download Queue screen can
/// show "Completed" / "Failed" sections even after the live queue row is
/// gone.
class DownloadHistoryEntry {
  final int? id;
  final int materialId;
  final String title;
  final String? courseCode;
  final bool succeeded;
  final String? error;
  final int fileSizeBytes;
  final DateTime occurredAt;

  const DownloadHistoryEntry({
    this.id,
    required this.materialId,
    required this.title,
    this.courseCode,
    required this.succeeded,
    this.error,
    this.fileSizeBytes = 0,
    required this.occurredAt,
  });

  Map<String, dynamic> toRow() => {
        if (id != null) 'id': id,
        'material_id': materialId,
        'title': title,
        'course_code': courseCode,
        'status': succeeded ? 'completed' : 'failed',
        'error': error,
        'file_size_bytes': fileSizeBytes,
        'occurred_at': occurredAt.toIso8601String(),
      };

  factory DownloadHistoryEntry.fromRow(Map<String, dynamic> r) => DownloadHistoryEntry(
        id: r['id'] as int?,
        materialId: r['material_id'] as int,
        title: r['title'] as String,
        courseCode: r['course_code'] as String?,
        succeeded: r['status'] == 'completed',
        error: r['error'] as String?,
        fileSizeBytes: (r['file_size_bytes'] as int?) ?? 0,
        occurredAt: DateTime.parse(r['occurred_at'] as String),
      );
}
