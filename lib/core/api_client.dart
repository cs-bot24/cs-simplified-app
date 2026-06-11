import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
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
      try {
        return jsonDecode(res.body);
      } on FormatException {
        // Server returned non-JSON (e.g. HTML from cold start / proxy error)
        dev.log('[API] Non-JSON response body: ${res.body.substring(0, res.body.length.clamp(0, 200))}',
            name: 'ApiClient');
        throw ApiException('Server returned an unexpected response. Please try again.',
            statusCode: res.statusCode);
      }
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
      // Never swallow the real message from the server —
      // return it directly unless it is blank.
      if (e.message.isNotEmpty &&
          !e.message.startsWith('Something went wrong')) {
        return e.message;
      }
      if (e.statusCode == 401) return 'Your session has expired. Please sign in again.';
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
    // Do NOT wrap login errors through _friendlyError.
    // The backend already returns precise messages (401 wrong creds, 403 disabled).
    // Wrapping through _friendlyError would replace them with "Session expired".
    final res = await http.post(Uri.parse('$_base/auth/login'),
        headers: _headers(),
        body: jsonEncode({'email': email, 'password': password}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getMe() async {
    try {
      final res = await http.get(Uri.parse('$_base/auth/me'), headers: _headers(auth: true));
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Home ecosystem (Phase 1.5A) ───────────────────────────────────────────

  /// Fetches the aggregated home screen payload in a single network call.
  /// Returns streak, daily quote, trending materials, recently viewed, and
  /// exam prep count — everything the home screen needs to render completely.
  static Future<Map<String, dynamic>> getHome() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/home'),
        headers: _headers(auth: true),
      );
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  /// Records today's app activity and returns the updated streak.
  /// Called fire-and-forget on every launch and foreground resume.
  /// Errors are swallowed by HomeProvider — this must never crash the app.
  static Future<Map<String, dynamic>> pingStreak() async {
    try {
      final res = await http.post(
        Uri.parse('$_base/streak/ping'),
        headers: _headers(auth: true),
      );
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  /// Logs a download event to the backend after a successful file save.
  /// Called fire-and-forget — errors are swallowed so a logging failure
  /// never interrupts the user experience.
  /// This feeds the analytics download count AND the trending materials query.
  static Future<void> logDownload(int materialId) async {
    try {
      await http.post(
        Uri.parse('$_base/downloads/$materialId'),
        headers: _headers(),
      );
    } catch (_) {}
  }

  /// Fetches all materials in the Exam Preparation category.
  static Future<List<dynamic>> getExamPrepMaterials() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/exam-prep/materials'),
        headers: _headers(auth: true),
      );
      return _handle(res) ?? [];
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  /// Submit or update a star rating (1–5) for a material.
  /// Returns the updated aggregate stats including the new average.
  static Future<Map<String, dynamic>> rateMaterial(
      int materialId, int rating) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/materials/$materialId/rate'),
        headers: _headers(auth: true),
        body: jsonEncode({'rating': rating}),
      );
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  /// Fetch the current user's rating + aggregate stats for a material.
  /// Called fire-and-forget on PDF open to pre-populate the rating dialog.
  static Future<Map<String, dynamic>> getMaterialRating(int materialId) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/materials/$materialId/rating'),
        headers: _headers(auth: true),
      );
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }
  /// Status 204 returns null body — that's handled by _handle() correctly.
  static Future<void> recordMaterialView(int materialId) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/materials/$materialId/view'),
        headers: _headers(auth: true),
      );
      if (res.statusCode != 204) _handle(res);
    } catch (_) {
      // View recording is best-effort — never propagate errors
    }
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

  static Future<Map<String, dynamic>> createCategory({
    required String name, String emoji = '📄',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/admin/categories'),
        headers: _headers(auth: true),
        body: jsonEncode({'category_name': name, 'emoji': emoji}),
      );
      return _handle(res) as Map<String, dynamic>;
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<Map<String, dynamic>> updateCategory({
    required int id, required String name, String emoji = '📄',
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$_base/admin/categories/$id'),
        headers: _headers(auth: true),
        body: jsonEncode({'category_name': name, 'emoji': emoji}),
      );
      return _handle(res) as Map<String, dynamic>;
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<void> deleteCategory(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$_base/admin/categories/$id'),
        headers: _headers(auth: true),
      );
      _handle(res);
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
        Uri.parse('$_base/materials/$id/title'),
        headers: _headers(auth: true),
        body: jsonEncode({'new_title': title}),
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


  // ── Material Requests (Student) ──────────────────────────────────────────
  static Future<void> createMaterialRequest({
    required String title,
    String message = '',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/material-requests'),
        headers: _headers(auth: true),
        body: jsonEncode({'title': title, 'message': message}),
      );
      _handle(res);
    } catch (e) {
      throw ApiException(_friendlyError(e));
    }
  }

  static Future<List<dynamic>> getMyMaterialRequests() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/material-requests'),
        headers: _headers(auth: true),
      );
      final data = _handle(res);
      return data is List ? data : [];
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Material Requests (Admin) ─────────────────────────────────────────────
  static Future<List<dynamic>> getAdminMaterialRequests({String? status}) async {
    try {
      final uri = Uri.parse('$_base/admin/material-requests')
          .replace(queryParameters: status != null ? {'status': status} : null);
      final res = await http.get(uri, headers: _headers(auth: true));
      final data = _handle(res);
      return data is List ? data : [];
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<void> updateMaterialRequestStatus(int id, String status) async {
    try {
      final res = await http.patch(
        Uri.parse('$_base/admin/material-requests/$id/status'),
        headers: _headers(auth: true),
        body: jsonEncode({'status': status}),
      );
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<void> replyToMaterialRequest(int id, String reply) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/admin/material-requests/$id/reply'),
        headers: _headers(auth: true),
        body: jsonEncode({'admin_reply': reply}),
      );
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<void> deleteMaterialRequest(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$_base/admin/material-requests/$id'),
        headers: _headers(auth: true),
      );
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Admin Stats (Phase 1.5C) ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> getAdminStats() async {
    try {
      debugPrint('[ApiClient] GET $_base/analytics token=${AppStorage.getToken() != null}');
      final res = await http.get(
        Uri.parse('$_base/analytics'),
        headers: _headers(auth: true),
      );
      return _handle(res) ?? {};
    } catch (e) {
      debugPrint('[ApiClient] getAdminStats threw: $e');
      throw ApiException(_friendlyError(e));
    }
  }

  // ── Announcements (Phase 1.5C) ────────────────────────────────────────────
  static Future<void> sendAnnouncement({
    required String title,
    required String message,
    String category = 'announcement',
    String targetType = 'global',
    int? targetId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('\$_base/admin/announcements'),
        headers: _headers(auth: true),
        body: jsonEncode({
          'title': title,
          'message': message,
          'category': category,
          'target_type': targetType,
          if (targetId != null) 'target_id': targetId,
        }),
      );
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<List<dynamic>> getAnnouncements() async {
    try {
      final res = await http.get(
        Uri.parse('\$_base/announcements'),
        headers: _headers(auth: true),
      );
      return _handle(res) ?? [];
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
      dev.log('[API] Notifications error: $e', name: 'ApiClient');
      return [];
    }
  }

  static Future<void> markNotificationRead(int id) async {
    try {
      final res = await http.post(Uri.parse('$_base/notifications/$id/read'),
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
      await http.post(Uri.parse('$_base/notifications/register-fcm'),
          headers: _headers(auth: true),
          body: jsonEncode({'fcm_token': fcmToken}));
    } catch (_) {}
  }

  // sendAdminNotification is kept for backwards compat but now correctly
  // routes to POST /admin/announcements so all admin-sent content is
  // stored in the announcements table and appears in the student feed.
  static Future<void> sendAdminNotification({
    required String title,
    required String body,
    String category = 'announcement',
  }) async {
    try {
      final res = await http.post(Uri.parse('$_base/admin/announcements'),
          headers: _headers(auth: true),
          body: jsonEncode({
            'title': title,
            'message': body,
            'category': category,
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

  static Future<List<dynamic>> getAdminContactMessages() async {
    try {
      final res = await http.get(Uri.parse('$_base/contact'),
          headers: _headers(auth: true));
      final data = _handle(res);
      return data is List ? data : [];
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }
  // ── Support Tickets (Student) ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> createSupportTicket({
    required String title,
    required String message,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/support-tickets'),
        headers: _headers(auth: true),
        body: jsonEncode({'title': title, 'message': message}),
      );
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<List<dynamic>> getMyTickets() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/support-tickets'),
        headers: _headers(auth: true),
      );
      final data = _handle(res);
      return data is List ? data : [];
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<Map<String, dynamic>> getMyTicket(int id) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/support-tickets/$id'),
        headers: _headers(auth: true),
      );
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Support Tickets (Admin) ────────────────────────────────────────────────

  static Future<List<dynamic>> getAdminTickets({String? status}) async {
    try {
      final uri = Uri.parse('$_base/admin/support-tickets')
          .replace(queryParameters: status != null ? {'status': status} : null);
      final res = await http.get(uri, headers: _headers(auth: true));
      final data = _handle(res);
      return data is List ? data : [];
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<Map<String, dynamic>> getAdminTicket(int id) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/admin/support-tickets/$id'),
        headers: _headers(auth: true),
      );
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<void> updateTicketStatus(int id, String status) async {
    try {
      final res = await http.patch(
        Uri.parse('$_base/admin/support-tickets/$id/status'),
        headers: _headers(auth: true),
        body: jsonEncode({'status': status}),
      );
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<void> replyToTicket(int id, String reply) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/admin/support-tickets/$id/reply'),
        headers: _headers(auth: true),
        body: jsonEncode({'admin_reply': reply}),
      );
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<void> deleteTicket(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$_base/admin/support-tickets/$id'),
        headers: _headers(auth: true),
      );
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Admin: mark contact message read ─────────────────────────────────────

  static Future<void> markContactMessageRead(int id) async {
    try {
      final res = await http.patch(
        Uri.parse('$_base/contact/$id/read'),
        headers: _headers(auth: true),
      );
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Admin: mark feedback read ─────────────────────────────────────────────

  static Future<void> markFeedbackRead(int id) async {
    try {
      final res = await http.patch(
        Uri.parse('$_base/feedback/$id/read'),
        headers: _headers(auth: true),
      );
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Account deletion ──────────────────────────────────────────────────────

  static Future<void> deleteAccount() async {
    try {
      final res = await http.delete(
        Uri.parse('$_base/users/me'),
        headers: _headers(auth: true),
      );
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Study ping (anti-cheat: called after 3 min of material reading) ───────

  static Future<Map<String, dynamic>> studyPing(int materialId) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/materials/$materialId/study-ping'),
        headers: _headers(auth: true),
      );
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Leaderboard ───────────────────────────────────────────────────────────

  static Future<dynamic> getLeaderboard({String mode = 'all_time'}) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/leaderboard?mode=$mode'),
        headers: _headers(auth: true),
      );
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<Map<String, dynamic>> getMyLeaderboardStats(
      {String mode = 'all_time'}) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/leaderboard/me?mode=$mode'),
        headers: _headers(auth: true),
      );
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<Map<String, dynamic>> updateLeaderboardSettings({
    String? displayName,
    bool? enabled,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (displayName != null) body['leaderboard_name'] = displayName;
      if (enabled != null)     body['leaderboard_enabled'] = enabled;
      final res = await http.patch(
        Uri.parse('$_base/users/me/leaderboard'),
        headers: _headers(auth: true),
        body: jsonEncode(body),
      );
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }
  // ── Achievements ──────────────────────────────────────────────────────────

  static Future<dynamic> getAchievements() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/achievements'),
        headers: _headers(auth: true),
      );
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<dynamic> getMyAchievements() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/achievements/me'),
        headers: _headers(auth: true),
      );
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }
  // ── Sharing ───────────────────────────────────────────────────────────────

  static Future<dynamic> getShareCardData() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/sharing/card-data'),
        headers: _headers(auth: true),
      );
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── AI Tutor (Phase 2.0) ──────────────────────────────────────────────────

  /// Submit an academic question to the AI Tutor.
  /// Returns a map with keys: question, response, subject, conversation_id, created_at.
  static Future<Map<String, dynamic>> askAi({
    required String question,
    String mode               = 'normal',
    String level              = 'intermediate',
    String? imageBase64,
    String? imageMimeType,
    // ── PDF Reader context ─────────────────────────────────────────────────
    int?    pdfMaterialId,
    String? pdfMaterialTitle,
    String? pdfCourseCode,
    String? pdfLevelName,
    String? pdfCategoryName,
    // ── Phase 4: Live conversation history ────────────────────────────────
    // List of {role, content} maps built from the in-memory _messages list.
    // Sending this gives the AI full session context so follow-up questions
    // ("explain again", "write the code", "why?", "continue") work correctly.
    List<Map<String, String>>? conversationHistory,
  }) async {
    try {
      final body = <String, dynamic>{
        'question':          question,
        'mode':              mode,
        'explanation_level': level,
        if (imageBase64      != null) 'image_base64':       imageBase64,
        if (imageMimeType    != null) 'image_mime_type':    imageMimeType,
        if (pdfMaterialId    != null) 'pdf_material_id':    pdfMaterialId,
        if (pdfMaterialTitle != null) 'pdf_material_title': pdfMaterialTitle,
        if (pdfCourseCode    != null) 'pdf_course_code':    pdfCourseCode,
        if (pdfLevelName     != null) 'pdf_level_name':     pdfLevelName,
        if (pdfCategoryName  != null) 'pdf_category_name':  pdfCategoryName,
        // Always send history — empty list means no prior context (first message)
        'conversation_history': conversationHistory ?? [],
      };
      final res = await http.post(
        Uri.parse('$_base/ai/ask'),
        headers: _headers(auth: true),
        body: jsonEncode(body),
      );
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  /// Generate practice questions on a topic.
  /// Generate practice questions.
  /// Phase 3: Pass sessionTopics + sessionConcepts for context-aware questions
  /// generated from what the student actually studied this session.
  static Future<Map<String, dynamic>> generatePracticeQuestions({
    required String topic,
    String level = 'intermediate',
    // Session context — from AiProvider session memory
    List<String>? sessionTopics,
    List<String>? sessionConcepts,
  }) async {
    try {
      final body = <String, dynamic>{
        'topic':             topic,
        'explanation_level': level,
        if (sessionTopics   != null && sessionTopics.isNotEmpty)
          'session_topics':   sessionTopics,
        if (sessionConcepts != null && sessionConcepts.isNotEmpty)
          'session_concepts': sessionConcepts,
      };
      final res = await http.post(
        Uri.parse('$_base/ai/practice'),
        headers: _headers(auth: true),
        body: jsonEncode(body),
      );
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  /// Generate study notes on a topic.
  /// Phase 3: Pass sessionTopics + sessionSummary for personalised notes
  /// that summarise what was actually learned in this session.
  static Future<Map<String, dynamic>> generateStudyNotes({
    required String topic,
    String level = 'intermediate',
    // Session context — from AiProvider session memory
    List<String>? sessionTopics,
    String?       sessionSummary,
  }) async {
    try {
      final body = <String, dynamic>{
        'topic':             topic,
        'explanation_level': level,
        if (sessionTopics   != null && sessionTopics.isNotEmpty)
          'session_topics':   sessionTopics,
        if (sessionSummary  != null)
          'session_summary':  sessionSummary,
      };
      final res = await http.post(
        Uri.parse('$_base/ai/study-notes'),
        headers: _headers(auth: true),
        body: jsonEncode(body),
      );
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  /// Fetch the user's AI conversation history (newest first).
  static Future<List<dynamic>> getAiHistory({int skip = 0, int limit = 20}) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/ai/history?skip=$skip&limit=$limit'),
        headers: _headers(auth: true),
      );
      final data = _handle(res);
      return data is List ? data : [];
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  /// Get today's usage stats and preferences.
  static Future<Map<String, dynamic>> getAiUsage() async {
    try {
      final res = await http.get(Uri.parse('$_base/ai/usage'), headers: _headers(auth: true));
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  /// Update the user's preferred explanation level.
  static Future<void> updateAiPreferences(String level) async {
    try {
      final res = await http.put(
        Uri.parse('$_base/ai/preferences'),
        headers: _headers(auth: true),
        body: jsonEncode({'explanation_level': level}),
      );
      _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  /// Get the user's current plan and feature flags.
  static Future<Map<String, dynamic>> getAiPlan() async {
    try {
      final res = await http.get(Uri.parse('$_base/ai/plan'), headers: _headers(auth: true));
      return _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  // ── Study Planner ─────────────────────────────────────────────────────────

  static Future<List<dynamic>> getStudyPlans() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/study-plans'),
        headers: _headers(auth: true),
      );
      return _handle(res) as List<dynamic>;
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<Map<String, dynamic>> createStudyPlan({
    String? courseCode,
    required String courseName,
    required String title,
    String? goal,
    required DateTime startDate,
    required DateTime endDate,
    required int studyHoursPerDay,
  }) async {
    try {
      final body = <String, dynamic>{
        'course_name':          courseName,
        'title':                title,
        'start_date':           startDate.toIso8601String().split('T').first,
        'end_date':             endDate.toIso8601String().split('T').first,
        'study_hours_per_day':  studyHoursPerDay,
        if (courseCode != null) 'course_code': courseCode,
        if (goal       != null) 'goal':        goal,
      };
      final res = await http.post(
        Uri.parse('$_base/study-plans'),
        headers: _headers(auth: true),
        body:    jsonEncode(body),
      );
      return _handle(res) as Map<String, dynamic>;
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<void> deleteStudyPlan(int planId) async {
    try {
      final res = await http.delete(
        Uri.parse('$_base/study-plans/$planId'),
        headers: _headers(auth: true),
      );
      if (res.statusCode != 204) _handle(res);
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<Map<String, dynamic>> completeStudySession(
      int planId, int sessionId) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/study-plans/$planId/sessions/$sessionId/complete'),
        headers: _headers(auth: true),
        body:    jsonEncode(<String, dynamic>{}),
      );
      return _handle(res) as Map<String, dynamic>;
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }

  static Future<List<dynamic>> getTodaysSessions() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/study-plans/today/sessions'),
        headers: _headers(auth: true),
      );
      return _handle(res) as List<dynamic>;
    } catch (e) { throw ApiException(_friendlyError(e)); }
  }
}