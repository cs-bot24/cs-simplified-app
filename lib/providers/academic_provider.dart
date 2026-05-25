import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/level_model.dart';
import '../models/semester_model.dart';
import '../models/course_model.dart';
import '../models/category_model.dart';
import '../models/material_model.dart';

class AcademicProvider extends ChangeNotifier {
  List<LevelModel>    _levels     = [];
  List<SemesterModel> _semesters  = [];
  List<CourseModel>   _courses    = [];
  List<CategoryModel> _categories = [];
  List<MaterialModel> _materials  = [];
  List<MaterialModel> _bookmarks  = [];
  List<MaterialModel> _searchResults = [];
  Map<String, dynamic> _analytics = {};

  bool    _loading = false;
  String? _error;

  List<LevelModel>    get levels        => _levels;
  List<SemesterModel> get semesters     => _semesters;
  List<CourseModel>   get courses       => _courses;
  List<CategoryModel> get categories    => _categories;
  List<MaterialModel> get materials     => _materials;
  List<MaterialModel> get bookmarks     => _bookmarks;
  List<MaterialModel> get searchResults => _searchResults;
  Map<String, dynamic> get analytics   => _analytics;
  bool                get loading       => _loading;
  String?             get error         => _error;

  void _set(bool v) { _loading = v; notifyListeners(); }

  Future<void> fetchLevels() async {
    _set(true);
    try {
      _levels = (await ApiClient.getLevels()).map((e) => LevelModel.fromJson(e)).toList();
      _error = null;
    } on ApiException catch (e) { _error = e.message; }
    finally { _set(false); }
  }

  Future<void> fetchSemesters(int levelId) async {
    _set(true);
    try {
      _semesters = (await ApiClient.getSemesters(levelId)).map((e) => SemesterModel.fromJson(e)).toList();
      _error = null;
    } on ApiException catch (e) { _error = e.message; }
    finally { _set(false); }
  }

  Future<void> fetchCourses(int semesterId) async {
    _set(true);
    try {
      _courses = (await ApiClient.getCourses(semesterId)).map((e) => CourseModel.fromJson(e)).toList();
      _error = null;
    } on ApiException catch (e) { _error = e.message; }
    finally { _set(false); }
  }

  Future<void> fetchCategories() async {
    if (_categories.isNotEmpty) return;
    try {
      _categories = (await ApiClient.getCategories()).map((e) => CategoryModel.fromJson(e)).toList();
    } on ApiException catch (e) { _error = e.message; }
  }

  Future<void> fetchMaterials(int courseId, {int? categoryId}) async {
    _set(true);
    try {
      _materials = (await ApiClient.getMaterials(courseId, categoryId: categoryId))
          .map((e) => MaterialModel.fromJson(e)).toList();
      _error = null;
    } on ApiException catch (e) { _error = e.message; }
    finally { _set(false); }
  }

  Future<void> fetchBookmarks() async {
    _set(true);
    try {
      _bookmarks = (await ApiClient.getBookmarks())
          .map((e) => MaterialModel.fromJson(e['material'])).toList();
      _error = null;
    } on ApiException catch (e) { _error = e.message; }
    finally { _set(false); }
  }

  Future<void> search(String q) async {
    _set(true);
    try {
      _searchResults = (await ApiClient.search(q)).map((e) => MaterialModel.fromJson(e)).toList();
      _error = null;
    } on ApiException catch (e) { _error = e.message; }
    finally { _set(false); }
  }

  Future<void> fetchAnalytics() async {
    try {
      _analytics = await ApiClient.getAnalytics();
      notifyListeners();
    } on ApiException catch (e) { _error = e.message; }
  }

  Future<void> toggleBookmark(int materialId) async {
    final exists = _bookmarks.any((m) => m.id == materialId);
    try {
      if (exists) {
        await ApiClient.removeBookmark(materialId);
        _bookmarks.removeWhere((m) => m.id == materialId);
      } else {
        await ApiClient.addBookmark(materialId);
        await fetchBookmarks();
      }
      notifyListeners();
    } on ApiException catch (e) { _error = e.message; }
  }

  bool isBookmarked(int id) => _bookmarks.any((m) => m.id == id);
  void clearSearch() { _searchResults = []; notifyListeners(); }
}
