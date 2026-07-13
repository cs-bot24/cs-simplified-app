import 'dart:async';
import 'dart:developer' as dev;

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/api_client.dart';
import '../../core/fcm_service.dart';
import '../../models/offline_material.dart';
import 'local_material_repository.dart';

/// Checks whether newer versions of already-downloaded materials exist on
/// the server, without ever touching the network path used to *open* a
/// local PDF (that stays 100% offline — see `OfflineMaterialService.open`).
///
/// Version comparison note: the backend doesn't yet expose a file-content
/// hash or an `updated_at` column on `Material` (uploads are immutable —
/// replacing a file's content creates a new material). `file_url` is
/// therefore the most reliable version signal available today: if it ever
/// changes for the same `material_id`, this treats it as a new version.
/// This is intentionally isolated behind [_versionOf] so wiring in a real
/// `updated_at`/hash field later is a one-line change.
class OfflineSyncService {
  OfflineSyncService({LocalMaterialRepository? repository})
      : _repo = repository ?? LocalMaterialRepository();

  final LocalMaterialRepository _repo;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _syncing = false;

  String _versionOf(Map<String, dynamic> serverMaterial) =>
      (serverMaterial['file_url'] as String?) ?? '';

  /// Manual trigger — e.g. Settings → Offline Materials → Check for Updates.
  /// Returns the number of materials found to have updates available.
  /// [notify] controls whether a system notification is fired — the manual
  /// "Check for Updates" button already shows its own in-app toast, so it
  /// passes false; background syncs (see [startAutoSync]) pass true.
  Future<int> checkForUpdates({bool notify = false}) async {
    if (_syncing) return 0;
    _syncing = true;
    var updatedCount = 0;
    try {
      final downloaded = await _repo.getAll();
      final byCourse = <int, List<OfflineMaterial>>{};
      for (final m in downloaded) {
        if (m.status != OfflineStatus.downloaded &&
            m.status != OfflineStatus.updateAvailable) continue;
        if (m.courseId == null) continue;
        byCourse.putIfAbsent(m.courseId!, () => []).add(m);
      }

      for (final entry in byCourse.entries) {
        List<dynamic> serverMaterials;
        try {
          serverMaterials = await ApiClient.getMaterials(entry.key);
        } catch (e) {
          dev.log('[OfflineSync] course ${entry.key} fetch failed: $e', name: 'OfflineSync');
          continue;
        }
        final byId = {for (final sm in serverMaterials) sm['id'] as int: sm};

        for (final local in entry.value) {
          final server = byId[local.materialId];
          if (server == null) continue; // material removed/unpublished server-side
          final serverVersion = _versionOf(server as Map<String, dynamic>);
          final hasUpdate = local.localVersion != null && local.localVersion != serverVersion;
          if (hasUpdate && local.status != OfflineStatus.updateAvailable) {
            await _repo.upsert(local.copyWith(
              serverVersion: serverVersion,
              status: OfflineStatus.updateAvailable,
            ));
            updatedCount++;
          } else if (!hasUpdate && local.status == OfflineStatus.updateAvailable) {
            // Server reverted / false alarm — clear the flag.
            await _repo.upsert(local.copyWith(status: OfflineStatus.downloaded));
          }
        }
      }
    } finally {
      _syncing = false;
    }
    if (notify && updatedCount > 0) {
      unawaited(FcmService.showUpdateAvailable(count: updatedCount).catchError((_) {}));
    }
    return updatedCount;
  }

  /// Starts listening for connectivity restoration and runs a background
  /// sync automatically each time the device regains internet.
  void startAutoSync() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        unawaited(checkForUpdates(notify: true));
      }
    });
  }

  void dispose() => _connectivitySub?.cancel();
}
