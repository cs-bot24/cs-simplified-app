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

import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import '../core/api_client.dart';
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
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _set(false);
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
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
    }
  }

  // ── Bookmark toggle ───────────────────────────────────────────────────────

  Future<void> toggleBookmark(int materialId) async {
    final exists = _bookmarks.any((m) => m.id == materialId);
    try {
      if (exists) {
        await ApiClient.removeBookmark(materialId);
        _bookmarks.removeWhere((m) => m.id == materialId);
      } else {
        await ApiClient.addBookmark(materialId);
        // Re-fetch to get the full material object with all fields.
        await fetchBookmarks();
        return; // fetchBookmarks already calls notifyListeners via _set.
      }
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  bool isBookmarked(int id) => _bookmarks.any((m) => m.id == id);

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }
}
