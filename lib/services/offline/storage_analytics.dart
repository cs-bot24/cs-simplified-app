import '../../models/offline_material.dart';
import 'local_material_repository.dart';
import 'storage_manager.dart';

/// Aggregated numbers for the "Offline Storage" dashboard: how much space
/// downloaded materials use, how much the device has free, and a
/// breakdown that feeds the storage graph and "largest files" list.
class StorageSnapshot {
  final int usedBytes;
  final int materialCount;
  final int? deviceFreeBytes;
  final int? deviceTotalBytes;
  final List<OfflineMaterial> largestFiles;
  final double averageFileBytes;

  /// Bytes used per course code, largest first — feeds a simple bar graph.
  final List<MapEntry<String, int>> byCourse;

  const StorageSnapshot({
    required this.usedBytes,
    required this.materialCount,
    required this.deviceFreeBytes,
    required this.deviceTotalBytes,
    required this.largestFiles,
    required this.averageFileBytes,
    required this.byCourse,
  });

  static const empty = StorageSnapshot(
    usedBytes: 0,
    materialCount: 0,
    deviceFreeBytes: null,
    deviceTotalBytes: null,
    largestFiles: [],
    averageFileBytes: 0,
    byCourse: [],
  );

  String get usedFormatted => formatBytes(usedBytes);
  String? get deviceFreeFormatted => deviceFreeBytes == null ? null : formatBytes(deviceFreeBytes!);
  String? get deviceTotalFormatted => deviceTotalBytes == null ? null : formatBytes(deviceTotalBytes!);
  String get averageFormatted => formatBytes(averageFileBytes.round());

  static String formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class StorageAnalytics {
  StorageAnalytics({LocalMaterialRepository? repository, StorageManager? storage})
      : _repo = repository ?? LocalMaterialRepository(),
        _storage = storage ?? StorageManager();

  final LocalMaterialRepository _repo;
  final StorageManager _storage;

  Future<StorageSnapshot> snapshot({int largestCount = 5}) async {
    final all = await _repo.getAll();
    final downloaded = all.where((m) => m.isDownloaded || m.hasUpdate).toList();
    final used = downloaded.fold<int>(0, (sum, m) => sum + m.fileSizeBytes);
    final largest = await _repo.largestFiles(limit: largestCount);
    final byCourseMap = await _repo.bytesByCourse();
    final byCourse = byCourseMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final freeBytes = await _storage.deviceFreeBytes();
    final totalBytes = await _storage.deviceTotalBytes();

    return StorageSnapshot(
      usedBytes: used,
      materialCount: downloaded.length,
      deviceFreeBytes: freeBytes,
      deviceTotalBytes: totalBytes,
      largestFiles: largest,
      averageFileBytes: downloaded.isEmpty ? 0 : used / downloaded.length,
      byCourse: byCourse,
    );
  }
}
