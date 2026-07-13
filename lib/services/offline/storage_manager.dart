import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DownloadNetworkPreference { wifiOnly, wifiAndData }

/// Auto-cleanup horizon for materials that haven't been opened recently.
enum AutoCleanupPolicy { never, after30Days, after60Days }

extension AutoCleanupPolicyX on AutoCleanupPolicy {
  int? get days => switch (this) {
        AutoCleanupPolicy.never => null,
        AutoCleanupPolicy.after30Days => 30,
        AutoCleanupPolicy.after60Days => 60,
      };

  String get label => switch (this) {
        AutoCleanupPolicy.never => 'Never',
        AutoCleanupPolicy.after30Days => '30 days',
        AutoCleanupPolicy.after60Days => '60 days',
      };
}

/// Owns the on-disk location of offline materials and the user-configurable
/// download/storage settings (network preference, auto-cleanup horizon).
///
/// Free-disk-space is estimated on a best-effort basis: Flutter has no
/// built-in cross-platform "bytes free" API without an extra native plugin,
/// so [hasEnoughSpaceFor] tries a lightweight probe and otherwise degrades
/// gracefully — the [DownloadManager] still catches out-of-space errors at
/// write time either way, so this is a UX nicety, not the only safety net.
class StorageManager {
  static const _kNetworkPref = 'offline_network_pref';
  static const _kCleanupPolicy = 'offline_cleanup_policy';

  Directory? _cachedDir;

  /// Directory all offline material files live in:
  /// `<app support dir>/offline_materials/`
  Future<Directory> offlineDirectory() async {
    if (_cachedDir != null) return _cachedDir!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'offline_materials'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _cachedDir = dir;
    return dir;
  }

  /// Deterministic, collision-safe file path for a material.
  Future<String> pathFor(int materialId, String title, String fileType) async {
    final dir = await offlineDirectory();
    final safeName = title
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return p.join(dir.path, '${materialId}_$safeName.$fileType');
  }

  /// Best-effort free-space check. Returns true when unknown (can't block
  /// the download on a value we don't have) — actual ENOSPC is still
  /// caught by [DownloadManager] during the write.
  Future<bool> hasEnoughSpaceFor(int requiredBytes) async {
    if (requiredBytes <= 0) return true;
    final free = await deviceFreeBytes();
    if (free == null) return true; // unknown — don't block
    return free > requiredBytes;
  }

  /// Free space on the device, in bytes.
  ///
  /// Always null for now: Flutter has no first-party cross-platform "bytes
  /// free" API, and after one failed build from an unverified third-party
  /// package API (see file_integrity_checker.dart's history), this
  /// intentionally does NOT pull in another one on a guess. Every caller
  /// (StorageAnalytics, the Storage Management screen, hasEnoughSpaceFor)
  /// already treats null as "unknown" and degrades cleanly — the device
  /// storage row just doesn't render rather than showing a wrong number.
  /// Swap this for a real plugin call once its exact API is confirmed
  /// against the pinned package version.
  Future<int?> deviceFreeBytes() async => null;

  Future<int?> deviceTotalBytes() async => null;

  // ── Settings ─────────────────────────────────────────────────────────────

  Future<DownloadNetworkPreference> getNetworkPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kNetworkPref);
    return DownloadNetworkPreference.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => DownloadNetworkPreference.wifiAndData,
    );
  }

  Future<void> setNetworkPreference(DownloadNetworkPreference pref) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNetworkPref, pref.name);
  }

  Future<AutoCleanupPolicy> getCleanupPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCleanupPolicy);
    return AutoCleanupPolicy.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => AutoCleanupPolicy.never,
    );
  }

  Future<void> setCleanupPolicy(AutoCleanupPolicy policy) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCleanupPolicy, policy.name);
  }
}
