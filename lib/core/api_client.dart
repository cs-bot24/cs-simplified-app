// core/api_client.dart — All HTTP calls to the FastAPI backend

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'storage.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiClient {
  static const _base = AppConstants.baseUrl;

  // ── Headers ────────────────────────────────────────────────────────────────

  static Map<String, String> _headers({bool auth = false}) {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = AppStorage.getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static dynamic _handle(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final detail = body['detail'] ?? 'Something went wrong.';
    throw ApiException(detail, statusCode: res.statusCode);
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/auth/register'),
      headers: _headers(),
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'password': password,
      }),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(
      Uri.parse('$_base/auth/me'),
      headers: _headers(auth: true),
    );
    return _handle(res);
  }

  // ── Levels ─────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getLevels() async {
    final res = await http.get(Uri.parse('$_base/levels'));
    return _handle(res);
  }

  // ── Semesters ──────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getSemesters(int levelId) async {
    final res = await http.get(Uri.parse('$_base/levels/$levelId/semesters'));
    return _handle(res);
  }

  // ── Courses ────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getCourses(int semesterId) async {
    final res = await http.get(Uri.parse('$_base/semesters/$semesterId/courses'));
    return _handle(res);
  }

  // ── Categories ─────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getCategories() async {
    final res = await http.get(Uri.parse('$_base/categories'));
    return _handle(res);
  }

  // ── Materials ──────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getMaterials(int courseId, {int? categoryId}) async {
    var url = '$_base/courses/$courseId/materials';
    if (categoryId != null) url += '?category_id=$categoryId';
    final res = await http.get(Uri.parse(url));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getMaterial(int materialId) async {
    final res = await http.get(Uri.parse('$_base/materials/$materialId'));
    return _handle(res);
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> search(String query) async {
    final res = await http.get(
      Uri.parse('$_base/search?q=${Uri.encodeComponent(query)}'),
    );
    return _handle(res);
  }

  // ── Bookmarks ──────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getBookmarks() async {
    final res = await http.get(
      Uri.parse('$_base/bookmarks'),
      headers: _headers(auth: true),
    );
    return _handle(res);
  }

  static Future<void> addBookmark(int materialId) async {
    final res = await http.post(
      Uri.parse('$_base/bookmarks/$materialId'),
      headers: _headers(auth: true),
    );
    _handle(res);
  }

  static Future<void> removeBookmark(int materialId) async {
    final res = await http.delete(
      Uri.parse('$_base/bookmarks/$materialId'),
      headers: _headers(auth: true),
    );
    _handle(res);
  }
}
