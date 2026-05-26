import 'dart:convert';
import 'dart:developer' as dev;
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
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final t = AppStorage.getToken();
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  static dynamic _handle(http.Response res) {
    dev.log('[API] ${res.request?.method} ${res.request?.url} → ${res.statusCode}',
        name: 'ApiClient');
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    String detail = 'Something went wrong (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      final raw = body['detail'];
      if (raw is List) {
        detail = raw.map((e) => e['msg'] ?? e.toString()).join(', ');
      } else if (raw is String) {
        detail = raw;
      }
    } catch (_) {}
    dev.log('[API] Error: $detail', name: 'ApiClient');
    throw ApiException(detail, statusCode: res.statusCode);
  }

  static String _friendlyError(dynamic e) {
    if (e is ApiException) {
      if (e.statusCode == 401) return 'Session expired. Please sign in again.';
      if (e.statusCode == 403) return 'Permission denied.';
      if (e.statusCode == 404) return 'Not found. Please try again later.';
      if (e.statusCode == 422) return 'Invalid data sent. Please check your input.';
      if (e.statusCode != null && e.statusCode! >= 500) return 'Server error. Please try again later.';
      return e.message;
    }
    final msg = e.toString().toLowerCase();
    if (msg.contains('socketexception') || msg.contains('connection refused') ||
        msg.contains('network')) return 'Unable to connect to server. Check your internet.';
    if (msg.contains('timeout')) return 'Connection timed out. Please try again.';
    return 'Unexpected error. Please try again.';
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String fullName, required String email, required String password,
  }) async {
    try {
      final res = await http.post(Uri.parse('$_base/auth/register'),
          headers: _headers(),
          body: jsonEncode({'full_name': fullName, 'email': email, 'password': password}));
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<Map<String, dynamic>> login({
    required String email, required String password,
  }) async {
    try {
      final res = await http.post(Uri.parse('$_base/auth/login'),
          headers: _headers(),
          body: jsonEncode({'email': email, 'password': password}));
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<Map<String, dynamic>> getMe() async {
    try {
      final res = await http.get(Uri.parse('$_base/auth/me'), headers: _headers(auth: true));
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Levels ────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getLevels() async {
    try {
      final res = await http.get(Uri.parse('$_base/levels'));
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<Map<String, dynamic>> createLevel(Map<String, dynamic> data) async {
    try {
      final res = await http.post(Uri.parse('$_base/levels'),
          headers: _headers(auth: true), body: jsonEncode(data));
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<void> updateLevel(int id, Map<String, dynamic> data) async {
    try {
      final res = await http.put(Uri.parse('$_base/levels/$id'),
          headers: _headers(auth: true), body: jsonEncode(data));
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<void> deleteLevel(int id) async {
    try {
      final res = await http.delete(Uri.parse('$_base/levels/$id'),
          headers: _headers(auth: true));
      if (res.statusCode != 204) _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Semesters ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getSemesters(int levelId) async {
    try {
      final res = await http.get(Uri.parse('$_base/levels/$levelId/semesters'));
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<Map<String, dynamic>> createSemester(Map<String, dynamic> data) async {
    try {
      final res = await http.post(Uri.parse('$_base/semesters'),
          headers: _headers(auth: true), body: jsonEncode(data));
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<void> updateSemester(int id, Map<String, dynamic> data) async {
    try {
      final res = await http.put(Uri.parse('$_base/semesters/$id'),
          headers: _headers(auth: true), body: jsonEncode(data));
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<void> deleteSemester(int id) async {
    try {
      final res = await http.delete(Uri.parse('$_base/semesters/$id'),
          headers: _headers(auth: true));
      if (res.statusCode != 204) _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Courses ───────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getCourses(int semesterId) async {
    try {
      final res = await http.get(Uri.parse('$_base/semesters/$semesterId/courses'));
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<Map<String, dynamic>> createCourse(Map<String, dynamic> data) async {
    try {
      final res = await http.post(Uri.parse('$_base/courses'),
          headers: _headers(auth: true), body: jsonEncode(data));
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<void> updateCourse(int id, Map<String, dynamic> data) async {
    try {
      final res = await http.put(Uri.parse('$_base/courses/$id'),
          headers: _headers(auth: true), body: jsonEncode(data));
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<void> deleteCourse(int id) async {
    try {
      final res = await http.delete(Uri.parse('$_base/courses/$id'),
          headers: _headers(auth: true));
      if (res.statusCode != 204) _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Categories ────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getCategories() async {
    try {
      final res = await http.get(Uri.parse('$_base/categories'));
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Materials ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getMaterials(int courseId, {int? categoryId}) async {
    try {
      var url = '$_base/courses/$courseId/materials';
      if (categoryId != null) url += '?category_id=$categoryId';
      final res = await http.get(Uri.parse(url));
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<void> deleteMaterial(int id) async {
    try {
      final res = await http.delete(Uri.parse('$_base/materials/$id'),
          headers: _headers(auth: true));
      if (res.statusCode != 204) _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<void> updateMaterialTitle(int id, String title) async {
    try {
      final res = await http.patch(
        Uri.parse('$_base/materials/$id/title?new_title=${Uri.encodeComponent(title)}'),
        headers: _headers(auth: true),
      );
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Search ────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> search(String q) async {
    try {
      final res = await http.get(Uri.parse('$_base/search?q=${Uri.encodeComponent(q)}'));
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Bookmarks ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getBookmarks() async {
    try {
      final res = await http.get(Uri.parse('$_base/bookmarks'), headers: _headers(auth: true));
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<void> addBookmark(int id) async {
    try {
      final res = await http.post(Uri.parse('$_base/bookmarks/$id'),
          headers: _headers(auth: true));
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<void> removeBookmark(int id) async {
    try {
      final res = await http.delete(Uri.parse('$_base/bookmarks/$id'),
          headers: _headers(auth: true));
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Analytics ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final res = await http.get(Uri.parse('$_base/analytics'),
          headers: _headers(auth: true));
      return _handle(res) ?? {};
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Version ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getVersion() async {
    try {
      final res = await http.get(Uri.parse('$_base/version'));
      return _handle(res) ?? {};
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Notifications ─────────────────────────────────────────────────────────
  static Future<List<dynamic>> getNotifications() async {
    try {
      final res = await http.get(Uri.parse('$_base/notifications'),
          headers: _headers(auth: true));
      final data = _handle(res);
      return data is List ? data : [];
    } catch (e) {
      dev.log('[API] Notifications not available: $e', name: 'ApiClient');
      return []; // graceful fallback — endpoint may not exist yet
    }
  }

  static Future<void> markNotificationRead(int id) async {
    try {
      final res = await http.patch(Uri.parse('$_base/notifications/$id/read'),
          headers: _headers(auth: true));
      _handle(res);
    } catch (_) {}
  }

  static Future<void> markAllNotificationsRead() async {
    try {
      final res = await http.patch(Uri.parse('$_base/notifications/read-all'),
          headers: _headers(auth: true));
      _handle(res);
    } catch (_) {}
  }

  static Future<void> deleteNotification(int id) async {
    try {
      final res = await http.delete(Uri.parse('$_base/notifications/$id'),
          headers: _headers(auth: true));
      if (res.statusCode != 204) _handle(res);
    } catch (_) {}
  }

  static Future<void> registerFcmToken(String fcmToken) async {
    if (AppStorage.getToken() == null) return;
    try {
      await http.post(Uri.parse('$_base/notifications/register-token'),
          headers: _headers(auth: true),
          body: jsonEncode({'fcm_token': fcmToken}));
    } catch (_) {}
  }

  static Future<void> sendAdminNotification({
    required String title,
    required String body,
    String? category,
  }) async {
    try {
      final res = await http.post(Uri.parse('$_base/notifications/broadcast'),
          headers: _headers(auth: true),
          body: jsonEncode({
            'title': title,
            'body': body,
            'category': category ?? 'announcement',
          }));
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Feedback ──────────────────────────────────────────────────────────────
  static Future<void> submitFeedback({
    required int rating,
    required String message,
    required String type,
  }) async {
    try {
      final res = await http.post(Uri.parse('$_base/feedback'),
          headers: _headers(auth: true),
          body: jsonEncode({'rating': rating, 'message': message, 'type': type}));
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<List<dynamic>> getAdminFeedback() async {
    try {
      final res = await http.get(Uri.parse('$_base/feedback'),
          headers: _headers(auth: true));
      final data = _handle(res);
      return data is List ? data : [];
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Contact ───────────────────────────────────────────────────────────────
  static Future<void> sendContactMessage({
    required String subject,
    required String message,
    required String type,
  }) async {
    try {
      final res = await http.post(Uri.parse('$_base/contact'),
          headers: _headers(auth: true),
          body: jsonEncode({'subject': subject, 'message': message, 'type': type}));
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }
}
