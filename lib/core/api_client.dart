import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'storage.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override String toString() => message;
}

class ApiClient {
  static const _base = AppConstants.baseUrl;

  static Map<String, String> _headers({bool auth = false}) {
    final h = {'Content-Type': 'application/json'};
    if (auth) {
      final t = AppStorage.getToken();
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  static dynamic _handle(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final detail = body['detail'] ?? 'Something went wrong.';
    throw ApiException(
      detail is List ? detail.map((e) => e['msg']).join(', ') : detail.toString(),
      statusCode: res.statusCode,
    );
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String fullName, required String email, required String password,
  }) async {
    final res = await http.post(Uri.parse('$_base/auth/register'),
        headers: _headers(),
        body: jsonEncode({'full_name': fullName, 'email': email, 'password': password}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> login({
    required String email, required String password,
  }) async {
    final res = await http.post(Uri.parse('$_base/auth/login'),
        headers: _headers(),
        body: jsonEncode({'email': email, 'password': password}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(Uri.parse('$_base/auth/me'), headers: _headers(auth: true));
    return _handle(res);
  }

  // ── Levels ────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getLevels() async {
    final res = await http.get(Uri.parse('$_base/levels'));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> createLevel(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$_base/levels'),
        headers: _headers(auth: true), body: jsonEncode(data));
    return _handle(res);
  }

  static Future<void> deleteLevel(int id) async {
    final res = await http.delete(Uri.parse('$_base/levels/$id'), headers: _headers(auth: true));
    if (res.statusCode != 204) _handle(res);
  }

  // ── Semesters ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getSemesters(int levelId) async {
    final res = await http.get(Uri.parse('$_base/levels/$levelId/semesters'));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> createSemester(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$_base/semesters'),
        headers: _headers(auth: true), body: jsonEncode(data));
    return _handle(res);
  }

  // ── Courses ───────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getCourses(int semesterId) async {
    final res = await http.get(Uri.parse('$_base/semesters/$semesterId/courses'));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> createCourse(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$_base/courses'),
        headers: _headers(auth: true), body: jsonEncode(data));
    return _handle(res);
  }

  static Future<void> deleteCourse(int id) async {
    final res = await http.delete(Uri.parse('$_base/courses/$id'), headers: _headers(auth: true));
    if (res.statusCode != 204) _handle(res);
  }

  // ── Categories ────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getCategories() async {
    final res = await http.get(Uri.parse('$_base/categories'));
    return _handle(res);
  }

  // ── Materials ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getMaterials(int courseId, {int? categoryId}) async {
    var url = '$_base/courses/$courseId/materials';
    if (categoryId != null) url += '?category_id=$categoryId';
    final res = await http.get(Uri.parse(url));
    return _handle(res);
  }

  static Future<void> deleteLevel2(int id) async {
    final res = await http.delete(Uri.parse('$_base/levels/$id'), headers: _headers(auth: true));
    if (res.statusCode != 204) _handle(res);
  }

  static Future<void> deleteMaterial(int id) async {
    final res = await http.delete(Uri.parse('$_base/materials/$id'), headers: _headers(auth: true));
    if (res.statusCode != 204) _handle(res);
  }

  static Future<void> updateMaterialTitle(int id, String title) async {
    final res = await http.patch(
      Uri.parse('$_base/materials/$id/title?new_title=${Uri.encodeComponent(title)}'),
      headers: _headers(auth: true),
    );
    _handle(res);
  }

  // ── Search ────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> search(String q) async {
    final res = await http.get(Uri.parse('$_base/search?q=${Uri.encodeComponent(q)}'));
    return _handle(res);
  }

  // ── Bookmarks ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getBookmarks() async {
    final res = await http.get(Uri.parse('$_base/bookmarks'), headers: _headers(auth: true));
    return _handle(res);
  }

  static Future<void> addBookmark(int id) async {
    final res = await http.post(Uri.parse('$_base/bookmarks/$id'), headers: _headers(auth: true));
    _handle(res);
  }

  static Future<void> removeBookmark(int id) async {
    final res = await http.delete(Uri.parse('$_base/bookmarks/$id'), headers: _headers(auth: true));
    _handle(res);
  }

  // ── Analytics ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getAnalytics() async {
    final res = await http.get(Uri.parse('$_base/analytics'), headers: _headers(auth: true));
    return _handle(res);
  }

  // ── Version ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getVersion() async {
    final res = await http.get(Uri.parse('$_base/version'));
    return _handle(res);
  }

  // ── Notifications ─────────────────────────────────────────────────────────
  static Future<List<dynamic>> getNotifications() async {
    final res = await http.get(
        Uri.parse('$_base/notifications'), headers: _headers(auth: true));
    return _handle(res);
  }

  static Future<void> markNotificationRead(int id) async {
    final res = await http.patch(
        Uri.parse('$_base/notifications/$id/read'), headers: _headers(auth: true));
    _handle(res);
  }

  static Future<void> markAllNotificationsRead() async {
    final res = await http.patch(
        Uri.parse('$_base/notifications/read-all'), headers: _headers(auth: true));
    _handle(res);
  }

  static Future<void> deleteNotification(int id) async {
    final res = await http.delete(
        Uri.parse('$_base/notifications/$id'), headers: _headers(auth: true));
    if (res.statusCode != 204) _handle(res);
  }

  static Future<void> registerFcmToken(String fcmToken) async {
    final token = AppStorage.getToken();
    if (token == null) return;
    try {
      await http.post(
        Uri.parse('$_base/notifications/register-token'),
        headers: _headers(auth: true),
        body: jsonEncode({'fcm_token': fcmToken}),
      );
    } catch (_) {}
  }

  static Future<void> sendAdminNotification({
    required String title,
    required String body,
    String? category,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/notifications/broadcast'),
      headers: _headers(auth: true),
      body: jsonEncode({'title': title, 'body': body, 'category': category ?? 'announcement'}),
    );
    _handle(res);
  }

  // ── Feedback ──────────────────────────────────────────────────────────────
  static Future<void> submitFeedback({
    required int rating,
    required String message,
    required String type,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/feedback'),
      headers: _headers(auth: true),
      body: jsonEncode({'rating': rating, 'message': message, 'type': type}),
    );
    _handle(res);
  }

  static Future<List<dynamic>> getAdminFeedback() async {
    final res = await http.get(
        Uri.parse('$_base/feedback'), headers: _headers(auth: true));
    return _handle(res);
  }

  // ── Contact ───────────────────────────────────────────────────────────────
  static Future<void> sendContactMessage({
    required String subject,
    required String message,
    required String type,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/contact'),
      headers: _headers(auth: true),
      body: jsonEncode({'subject': subject, 'message': message, 'type': type}),
    );
    _handle(res);
  }
}
