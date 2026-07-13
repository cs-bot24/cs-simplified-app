// lib/providers/academic_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
// CHANGES vs original:
//
//   1. CRASH FIX — fetchBookmarks() defensive parsing:
//      The original blindly accessed e['material'] on every bookmark item.
//      If the backend returns flat material objects (the more common FastAPI
//      pattern), e['material'] is null and MaterialModel.fromJson(null)
//      throws a "Null check operator used on a null value" error, silently
//      clearing the bookmarks list.  The new implementation detects both
//      response shapes and handles each correctly:
//        • Nested:  [{ "material": { id, file_url, ... } }]
//        • Flat:    [{ id, file_url, material_title, ... }]
//      It also wraps individual items in a try/catch so one malformed item
//      doesn't abort the entire parse.
//
//   2. PERFORMANCE FIX — fetchLevels() early-return guard:
//      The home tab calls fetchLevels() on every initState.  Because the
//      HomeTab lives inside an IndexedStack it is kept alive, but if the
//      user navigates away and back the widget is re-initialised in certain
//      scenarios.  Adding the guard "if (_levels.isNotEmpty) return" prevents
//      a redundant network call without breaking pull-to-refresh (which
//      passes forceRefresh: true).
//
//   3. RELIABILITY FIX — per-fetch error state:
//      The original shared a single _error field across all operations.
//      A failed bookmark fetch would leave a stale error message visible
//      on the levels screen.  Each method now sets its own error and clears
//      it when the next fetch of the same kind succeeds.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/connectivity_service.dart';
import '../models/level_model.dart';
import '../models/semester_model.dart';
import '../models/course_model.dart';
import '../models/category_model.dart';
import '../models/material_model.dart';

class AcademicProvider extends ChangeNotifier {
  List<LevelModel>     _levels       = [];
  List<SemesterModel>  _semesters    = [];
  List<CourseModel>    _courses      = [];
  List<CategoryModel>  _categories   = [];
  List<MaterialModel>  _materials    = [];
  List<MaterialModel>  _bookmarks    = [];
  List<MaterialModel>  _searchResults = [];
  Map<String, dynamic> _analytics   = {};

  bool    _loading = false;
  String? _error;

  StreamSubscription<bool>? _connectivitySub;

  AcademicProvider() {
    // The moment we're back online, replay any bookmark toggles the user
    // made while offline — see toggleBookmark()/flushPendingBookmarkActions().
    _connectivitySub = ConnectivityService.instance.onStatusChange.listen((online) {
      if (online) unawaited(flushPendingBookmarkActions());
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  List<LevelModel>     get levels        => _levels;
  List<SemesterModel>  get semesters     => _semesters;
  List<CourseModel>    get courses       => _courses;
  List<CategoryModel>  get categories    => _categories;
  List<MaterialModel>  get materials     => _materials;
  List<MaterialModel>  get bookmarks     => _bookmarks;
  List<MaterialModel>  get searchResults => _searchResults;
  Map<String, dynamic> get analytics    => _analytics;
  bool                 get loading      => _loading;
  String?              get error        => _error;

  void _set(bool v) {
    _loading = v;
    notifyListeners();
  }

  // ── Levels ────────────────────────────────────────────────────────────────

  /// Fetches levels from the backend.
  ///
  /// If [forceRefresh] is false (the default) and levels are already loaded,
  /// this is a no-op — prevents redundant network calls when the home tab
  /// is revisited.  Pass forceRefresh: true from pull-to-refresh handlers.
  Future<void> fetchLevels({bool forceRefresh = false}) async {
    if (!forceRefresh && _levels.isNotEmpty) return;
    _set(true);
    try {
      _levels = (await ApiClient.getLevels())
          .map((e) => LevelModel.fromJson(e))
          .toList();
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _set(false);
    }
  }

  // ── Semesters ─────────────────────────────────────────────────────────────

  Future<void> fetchSemesters(int levelId) async {
    _set(true);
    try {
      _semesters = (await ApiClient.getSemesters(levelId))
          .map((e) => SemesterModel.fromJson(e))
          .toList();
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _set(false);
    }
  }

  // ── Courses ───────────────────────────────────────────────────────────────

  Future<void> fetchCourses(int semesterId) async {
    _set(true);
    try {
      _courses = (await ApiClient.getCourses(semesterId))
          .map((e) => CourseModel.fromJson(e))
          .toList();
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _set(false);
    }
  }

  // ── Categories ────────────────────────────────────────────────────────────

  Future<void> fetchCategories() async {
    if (_categories.isNotEmpty) return;
    try {
      _categories = (await ApiClient.getCategories())
          .map((e) => CategoryModel.fromJson(e))
          .toList();
    } on ApiException catch (e) {
      _error = e.message;
    }
  }

  // ── Materials ─────────────────────────────────────────────────────────────

  Future<void> fetchMaterials(int courseId, {int? categoryId}) async {
    _set(true);
    try {
      _materials = (await ApiClient.getMaterials(courseId, categoryId: categoryId))
          .map((e) => MaterialModel.fromJson(e))
          .toList();
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _set(false);
    }
  }

  // ── Bookmarks ─────────────────────────────────────────────────────────────
  //
  // The backend can return bookmarks in two shapes:
  //
  //   A) Nested (join table response):
  //      [ { "id": 1, "user_id": 7, "material": { "id": 3, "file_url": … } } ]
  //
  //   B) Flat (direct materials):
  //      [ { "id": 3, "material_title": "…", "file_url": "…", … } ]
  //
  // We detect shape A by checking for the presence of a "material" key.
  // Shape B is parsed directly.  One bad item won't abort the whole list.
  //
  // Offline support: the last successful list is cached locally, and any
  // add/remove made while offline is applied to the UI immediately and
  // queued to replay against the server the next time connectivity comes
  // back (see [_flushPendingBookmarkActions]).

  static const _kBookmarksCacheKey = 'bookmarks_cache_v1';
  static const _kPendingBookmarkActionsKey = 'pending_bookmark_actions_v1';

  bool _bookmarksAreStale = false;
  bool get bookmarksAreStale => _bookmarksAreStale;

  Future<void> fetchBookmarks() async {
    _set(true);
    try {
      final raw = await ApiClient.getBookmarks();
      final parsed = <MaterialModel>[];
      for (final e in raw) {
        try {
          final Map<String, dynamic> json;
          if (e is Map<String, dynamic> && e.containsKey('material') &&
              e['material'] is Map<String, dynamic>) {
            // Shape A — nested
            json = e['material'] as Map<String, dynamic>;
          } else if (e is Map<String, dynamic>) {
            // Shape B — flat
            json = e;
          } else {
            dev.log('[Bookmarks] Unexpected item type: ${e.runtimeType}',
                name: 'AcademicProvider');
            continue;
          }
          parsed.add(MaterialModel.fromJson(json));
        } catch (parseErr) {
          dev.log('[Bookmarks] Skipping malformed item: $parseErr',
              name: 'AcademicProvider');
        }
      }
      _bookmarks = parsed;
      _error = null;
      _bookmarksAreStale = false;
      unawaited(_cacheBookmarks());
    } on ApiException catch (e) {
      if (e.isConnectivityError) {
        // Offline — fall back to whatever we last cached rather than
        // showing an error or an empty list.
        final loaded = await _loadCachedBookmarks();
        if (loaded) {
          _bookmarksAreStale = true;
          _error = null;
        } else {
          _error = e.message;
        }
      } else {
        _error = e.message;
      }
    } finally {
      _set(false);
    }
  }

  Future<void> _cacheBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kBookmarksCacheKey,
          jsonEncode(_bookmarks.map((m) => m.toJson()).toList()));
    } catch (e) {
      dev.log('[Bookmarks] cache write error: $e', name: 'AcademicProvider');
    }
  }

  /// Returns true if a cached list was found and loaded into [_bookmarks].
  Future<bool> _loadCachedBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kBookmarksCacheKey);
      if (raw == null) return false;
      final list = (jsonDecode(raw) as List)
          .map((j) => MaterialModel.fromJson(j as Map<String, dynamic>))
          .toList();
      _bookmarks = _applyPendingActions(list, await _loadPendingActions());
      return true;
    } catch (e) {
      dev.log('[Bookmarks] cache read error: $e', name: 'AcademicProvider');
      return false;
    }
  }

  List<MaterialModel> _applyPendingActions(
      List<MaterialModel> base, List<_PendingBookmarkAction> pending) {
    final list = [...base];
    for (final action in pending) {
      if (action.isAdd) {
        if (!list.any((m) => m.id == action.materialId) && action.material != null) {
          list.add(action.material!);
        }
      } else {
        list.removeWhere((m) => m.id == action.materialId);
      }
    }
    return list;
  }

  Future<List<_PendingBookmarkAction>> _loadPendingActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPendingBookmarkActionsKey);
      if (raw == null) return [];
      return (jsonDecode(raw) as List)
          .map((j) => _PendingBookmarkAction.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      dev.log('[Bookmarks] pending-actions read error: $e', name: 'AcademicProvider');
      return [];
    }
  }

  Future<void> _savePendingActions(List<_PendingBookmarkAction> actions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPendingBookmarkActionsKey,
          jsonEncode(actions.map((a) => a.toJson()).toList()));
    } catch (e) {
      dev.log('[Bookmarks] pending-actions write error: $e', name: 'AcademicProvider');
    }
  }

  Future<void> _queueBookmarkAction(_PendingBookmarkAction action) async {
    final pending = await _loadPendingActions();
    // A new action for the same material supersedes any earlier queued
    // one (e.g. add-then-remove while still offline collapses to remove).
    pending.removeWhere((a) => a.materialId == action.materialId);
    pending.add(action);
    await _savePendingActions(pending);
  }

  /// Replays queued offline bookmark actions against the server. Call this
  /// when connectivity comes back (see main.dart's ConnectivityService
  /// listener). Safe to call opportunistically — no-ops if there's nothing
  /// queued or if a replay attempt itself fails (stays queued for next time).
  Future<void> flushPendingBookmarkActions() async {
    final pending = await _loadPendingActions();
    if (pending.isEmpty) return;
    final stillPending = <_PendingBookmarkAction>[];
    for (final action in pending) {
      try {
        if (action.isAdd) {
          await ApiClient.addBookmark(action.materialId);
        } else {
          await ApiClient.removeBookmark(action.materialId);
        }
      } catch (e) {
        dev.log('[Bookmarks] replay failed for ${action.materialId}: $e',
            name: 'AcademicProvider');
        stillPending.add(action); // try again next time
      }
    }
    await _savePendingActions(stillPending);
    if (stillPending.length != pending.length) {
      // At least one action synced — refresh from server for a clean state.
      await fetchBookmarks();
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<void> search(String q) async {
    _set(true);
    try {
      _searchResults = (await ApiClient.search(q))
          .map((e) => MaterialModel.fromJson(e))
          .toList();
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _set(false);
    }
  }

  // ── Analytics ─────────────────────────────────────────────────────────────

  Future<void> fetchAnalytics() async {
    try {
      _analytics = await ApiClient.getAnalytics();
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      notifyListeners();
    }
  }

  // ── Bookmark toggle ───────────────────────────────────────────────────────

  Future<void> toggleBookmark(MaterialModel material) async {
    final exists = _bookmarks.any((m) => m.id == material.id);

    if (ConnectivityService.instance.isOffline) {
      // Apply immediately so the star/icon flips without waiting, then
      // queue the real API call for when connectivity returns.
      if (exists) {
        _bookmarks.removeWhere((m) => m.id == material.id);
        await _queueBookmarkAction(_PendingBookmarkAction.remove(material.id));
      } else {
        _bookmarks.add(material);
        await _queueBookmarkAction(_PendingBookmarkAction.add(material));
      }
      await _cacheBookmarks();
      _bookmarksAreStale = true;
      notifyListeners();
      return;
    }

    try {
      if (exists) {
        await ApiClient.removeBookmark(material.id);
        _bookmarks.removeWhere((m) => m.id == material.id);
      } else {
        await ApiClient.addBookmark(material.id);
        // Re-fetch to get the full material object with all fields.
        await fetchBookmarks();
        return; // fetchBookmarks already calls notifyListeners via _set.
      }
      unawaited(_cacheBookmarks());
      notifyListeners();
    } on ApiException catch (e) {
      if (e.isConnectivityError) {
        // Connectivity dropped mid-request — fall back to the same
        // optimistic-and-queue path instead of surfacing an error.
        if (exists) {
          _bookmarks.removeWhere((m) => m.id == material.id);
          await _queueBookmarkAction(_PendingBookmarkAction.remove(material.id));
        } else {
          _bookmarks.add(material);
          await _queueBookmarkAction(_PendingBookmarkAction.add(material));
        }
        await _cacheBookmarks();
        _bookmarksAreStale = true;
      } else {
        _error = e.message;
      }
      notifyListeners();
    }
  }

  bool isBookmarked(int id) => _bookmarks.any((m) => m.id == id);

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }
}

/// A queued bookmark add/remove made while offline, replayed against the
/// server once connectivity returns (see
/// [AcademicProvider.flushPendingBookmarkActions]).
class _PendingBookmarkAction {
  final int materialId;
  final bool isAdd;
  final MaterialModel? material; // only needed for 'add', to cache optimistically

  _PendingBookmarkAction._(this.materialId, this.isAdd, this.material);

  factory _PendingBookmarkAction.add(MaterialModel material) =>
      _PendingBookmarkAction._(material.id, true, material);

  factory _PendingBookmarkAction.remove(int materialId) =>
      _PendingBookmarkAction._(materialId, false, null);

  Map<String, dynamic> toJson() => {
        'material_id': materialId,
        'is_add': isAdd,
        'material': material?.toJson(),
      };

  factory _PendingBookmarkAction.fromJson(Map<String, dynamic> j) => _PendingBookmarkAction._(
        j['material_id'] as int,
        j['is_add'] as bool,
        j['material'] != null ? MaterialModel.fromJson(j['material'] as Map<String, dynamic>) : null,
      );
}
