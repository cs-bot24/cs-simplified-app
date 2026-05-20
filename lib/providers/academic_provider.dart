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

  bool    _loading = false;
  String? _error;

  List<LevelModel>    get levels        => _levels;
  List<SemesterModel> get semesters     => _semesters;
  List<CourseModel>   get courses       => _courses;
  List<CategoryModel> get categories    => _categories;
  List<MaterialModel> get materials     => _materials;
  List<MaterialModel> get bookmarks     => _bookmarks;
  List<MaterialModel> get searchResults => _searchResults;
  bool                get loading       => _loading;
  String?             get error         => _error;

  void _setLoading(bool v) { _loading = v; notifyListeners(); }
  void _setError(String? v) { _error = v; notifyListeners(); }

  Future<void> fetchLevels() async {
    _setLoading(true);
    try {
      final data = await ApiClient.getLevels();
      _levels = data.map((e) => LevelModel.fromJson(e)).toList();
      _error = null;
    } on ApiException catch (e) { _setError(e.message); }
    finally { _setLoading(false); }
  }

  Future<void> fetchSemesters(int levelId) async {
    _setLoading(true);
    try {
      final data = await ApiClient.getSemesters(levelId);
      _semesters = data.map((e) => SemesterModel.fromJson(e)).toList();
      _error = null;
    } on ApiException catch (e) { _setError(e.message); }
    finally { _setLoading(false); }
  }

  Future<void> fetchCourses(int semesterId) async {
    _setLoading(true);
    try {
      final data = await ApiClient.getCourses(semesterId);
      _courses = data.map((e) => CourseModel.fromJson(e)).toList();
      _error = null;
    } on ApiException catch (e) { _setError(e.message); }
    finally { _setLoading(false); }
  }

  Future<void> fetchCategories() async {
    if (_categories.isNotEmpty) return;
    try {
      final data = await ApiClient.getCategories();
      _categories = data.map((e) => CategoryModel.fromJson(e)).toList();
    } on ApiException catch (e) { _setError(e.message); }
  }

  Future<void> fetchMaterials(int courseId, {int? categoryId}) async {
    _setLoading(true);
    try {
      final data = await ApiClient.getMaterials(courseId, categoryId: categoryId);
      _materials = data.map((e) => MaterialModel.fromJson(e)).toList();
      _error = null;
    } on ApiException catch (e) { _setError(e.message); }
    finally { _setLoading(false); }
  }

  Future<void> fetchBookmarks() async {
    _setLoading(true);
    try {
      final data = await ApiClient.getBookmarks();
      _bookmarks = data
          .map((e) => MaterialModel.fromJson(e['material']))
          .toList();
      _error = null;
    } on ApiException catch (e) { _setError(e.message); }
    finally { _setLoading(false); }
  }

  Future<void> search(String query) async {
    _setLoading(true);
    try {
      final data = await ApiClient.search(query);
      _searchResults = data.map((e) => MaterialModel.fromJson(e)).toList();
      _error = null;
    } on ApiException catch (e) { _setError(e.message); }
    finally { _setLoading(false); }
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
    } on ApiException catch (e) { _setError(e.message); }
  }

  bool isBookmarked(int materialId) =>
      _bookmarks.any((m) => m.id == materialId);

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }
}
