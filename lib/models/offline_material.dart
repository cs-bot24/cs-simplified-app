import 'dart:io';

/// Represents a PDF that has been downloaded to local device storage.
///
/// Stored as a JSON list in SharedPreferences by OfflineProvider.
/// The filePath points to the actual file on disk — if the user deletes
/// it through the phone's Files app, fileExists returns false and the
/// OfflineScreen shows a "file missing" state instead of crashing.
class OfflineMaterial {
  final int materialId;
  final String title;
  final String filePath;
  final int fileSizeBytes;
  final DateTime downloadedAt;
  final String? courseCode;

  const OfflineMaterial({
    required this.materialId,
    required this.title,
    required this.filePath,
    required this.fileSizeBytes,
    required this.downloadedAt,
    this.courseCode,
  });

  /// True if the file still exists on disk.
  /// Checked when the Offline tab loads to detect files the user
  /// deleted through the phone's own Files / Downloads app.
  bool get fileExists => File(filePath).existsSync();

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
    final diff = DateTime.now().difference(downloadedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Map<String, dynamic> toJson() => {
        'materialId': materialId,
        'title': title,
        'filePath': filePath,
        'fileSizeBytes': fileSizeBytes,
        'downloadedAt': downloadedAt.toIso8601String(),
        'courseCode': courseCode,
      };

  factory OfflineMaterial.fromJson(Map<String, dynamic> j) => OfflineMaterial(
        materialId: j['materialId'] as int,
        title: j['title'] as String,
        filePath: j['filePath'] as String,
        fileSizeBytes: j['fileSizeBytes'] as int,
        downloadedAt: DateTime.parse(j['downloadedAt'] as String),
        courseCode: j['courseCode'] as String?,
      );
}
