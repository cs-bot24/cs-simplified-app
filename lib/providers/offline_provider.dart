import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/offline_material.dart';

/// Manages the registry of locally downloaded PDF materials.
///
/// Architecture:
///   All state lives in SharedPreferences as a JSON list —
///   no backend involvement needed for offline storage.
///   The actual PDF files live in the device's Downloads folder
///   (or app-scoped storage as fallback).
///
/// Registration: must be in root MultiProvider so that:
///   • pdf_viewer_screen.dart can call addDownload() after saving
///   • materials_screen.dart can call isDownloaded() for the badge
///   • offline_screen.dart can read materials and call remove()
///
/// Initialisation: call loadFromStorage() once on app start
///   (done in _HomeTabState.initState alongside other providers).
class OfflineProvider extends ChangeNotifier {
  static const _storageKey = 'offline_materials_v1';

  List<OfflineMaterial> _materials = [];

  List<OfflineMaterial> get materials => List.unmodifiable(_materials);
  int get count => _materials.length;

  /// True if a material with this ID has been downloaded and the
  /// file still exists on disk.
  bool isDownloaded(int materialId) =>
      _materials.any((m) => m.materialId == materialId && m.fileExists);

  /// Total bytes used by all downloaded materials.
  String get totalStorageUsed {
    final total = _materials.fold<int>(0, (sum, m) => sum + m.fileSizeBytes);
    if (total == 0) return '0 KB';
    if (total < 1024 * 1024) {
      return '${(total / 1024).toStringAsFixed(0)} KB';
    }
    return '${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Initialisation ─────────────────────────────────────────────────────────

  /// Load persisted downloads from SharedPreferences.
  /// Automatically removes stale entries where the file no longer
  /// exists (deleted via Files app, storage cleared, etc.)
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;

      final list = jsonDecode(raw) as List;
      _materials = list
          .map((e) => OfflineMaterial.fromJson(e as Map<String, dynamic>))
          .toList();

      // Prune entries whose files were deleted outside the app
      final before = _materials.length;
      _materials.removeWhere((m) => !m.fileExists);
      if (_materials.length != before) {
        await _persist();
        dev.log(
          '[Offline] Pruned ${before - _materials.length} stale entries',
          name: 'OfflineProvider',
        );
      }

      notifyListeners();
    } catch (e) {
      dev.log('[Offline] Load error: $e', name: 'OfflineProvider');
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Register a newly downloaded material.
  /// If the same material was downloaded before, the old entry is
  /// replaced so we never have duplicates for the same materialId.
  /// Newest downloads appear first in the list.
  Future<void> addDownload(OfflineMaterial material) async {
    _materials.removeWhere((m) => m.materialId == material.materialId);
    _materials.insert(0, material);
    await _persist();
    notifyListeners();
  }

  /// Delete the file from disk and remove the registry entry.
  /// Errors during file deletion are logged but do not prevent
  /// the registry entry from being removed.
  Future<void> remove(int materialId) async {
    final entry = _materials
        .where((m) => m.materialId == materialId)
        .firstOrNull;

    if (entry != null) {
      try {
        final file = File(entry.filePath);
        if (await file.exists()) await file.delete();
      } catch (e) {
        dev.log('[Offline] File delete error: $e', name: 'OfflineProvider');
      }
    }

    _materials.removeWhere((m) => m.materialId == materialId);
    await _persist();
    notifyListeners();
  }

  // ── Storage ────────────────────────────────────────────────────────────────

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(_materials.map((m) => m.toJson()).toList()),
      );
    } catch (e) {
      dev.log('[Offline] Persist error: $e', name: 'OfflineProvider');
    }
  }
}
