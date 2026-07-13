import '../../models/offline_material.dart';
import 'local_material_repository.dart';

/// Reading history for the Offline Library's "Recently Opened" rail.
///
/// Deliberately thin — `last_opened_at`/`last_opened_page` already live on
/// `offline_materials` (Phase 1), this just gives that query its own named
/// entry point per the suggested Phase 2 architecture, and is the natural
/// place to grow real history (e.g. a full open-events log) later without
/// touching callers.
class ReadingHistoryRepository {
  ReadingHistoryRepository({LocalMaterialRepository? repository})
      : _repo = repository ?? LocalMaterialRepository();

  final LocalMaterialRepository _repo;

  Future<List<OfflineMaterial>> recentlyOpened({int limit = 10}) =>
      _repo.recentlyOpened(limit: limit);
}
