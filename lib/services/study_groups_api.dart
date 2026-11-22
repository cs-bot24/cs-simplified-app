// Study Groups: thin wrapper over ApiClient.request (all calls are authenticated).

import '../core/api_client.dart';
import '../models/study_group.dart';

/// Message to show the student for any failure.
String groupErrorMessage(Object e) =>
    e is ApiException ? e.message : 'Something went wrong. Please try again.';

class StudyGroupsApi {
  StudyGroupsApi._();

  static List<dynamic> _list(dynamic res, String key) {
    if (res is Map && res[key] is List) return res[key] as List<dynamic>;
    return const [];
  }

  static Future<List<StudyGroup>> myGroups() async {
    final res = await ApiClient.request('GET', '/groups/mine');
    return _list(res, 'groups')
        .map((e) => StudyGroup.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<List<StudyGroup>> discover({
    String query = '',
    int offset = 0,
    int limit = 20,
  }) async {
    final res = await ApiClient.request('GET', '/groups/discover', query: {
      if (query.trim().isNotEmpty) 'q': query.trim(),
      'offset': '$offset',
      'limit': '$limit',
    });
    return _list(res, 'groups')
        .map((e) => StudyGroup.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<String> nicknameHint() async {
    try {
      final res = await ApiClient.request('GET', '/groups/nickname-hint');
      if (res is Map && res['nickname'] is String) return res['nickname'] as String;
    } catch (_) {}
    return '';
  }

  static Future<StudyGroup> create({
    required String name,
    required String description,
    required String icon,
    required String privacy,
    required int maxMembers,
    required String nickname,
  }) async {
    final res = await ApiClient.request('POST', '/groups', body: {
      'name': name,
      'description': description,
      'icon': icon,
      'privacy': privacy,
      'max_members': maxMembers,
      'nickname': nickname,
    });
    return StudyGroup.fromJson(Map<String, dynamic>.from(res as Map));
  }

  static Future<StudyGroup> detail(int id) async {
    final res = await ApiClient.request('GET', '/groups/$id');
    return StudyGroup.fromJson(Map<String, dynamic>.from(res as Map));
  }

  static Future<List<GroupMember>> members(int id) async {
    final res = await ApiClient.request('GET', '/groups/$id/members');
    return _list(res, 'members')
        .map((e) => GroupMember.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<StudyGroup> join(int id, String nickname) async {
    final res = await ApiClient.request('POST', '/groups/$id/join',
        body: {'nickname': nickname});
    return StudyGroup.fromJson(Map<String, dynamic>.from(res as Map));
  }

  static Future<StudyGroup> joinByCode(String code, String nickname) async {
    final res = await ApiClient.request('POST', '/groups/join-by-code',
        body: {'code': code, 'nickname': nickname});
    return StudyGroup.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Returns true when the group was deleted because you were the last member.
  static Future<bool> leave(int id) async {
    final res = await ApiClient.request('POST', '/groups/$id/leave');
    return res is Map && res['group_deleted'] == true;
  }

  // ── Chat ─────────────────────────────────────────────────────────────────

  /// No cursor = latest page. [afterId] = only newer messages (polling).
  /// [beforeId] = older messages (scrolling up).
  static Future<MessagePage> messages(
    int groupId, {
    int afterId = 0,
    int beforeId = 0,
    int limit = 50,
  }) async {
    final res = await ApiClient.request('GET', '/groups/$groupId/messages', query: {
      if (afterId > 0) 'after_id': '$afterId',
      if (beforeId > 0) 'before_id': '$beforeId',
      'limit': '$limit',
    });
    final list = _list(res, 'messages')
        .map((e) => GroupMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final older = res is Map && res['has_older'] == true;
    return MessagePage(list, older);
  }

  static Future<GroupMessage> sendMessage(int groupId,
      {String body = '', int? materialId}) async {
    final res = await ApiClient.request('POST', '/groups/$groupId/messages', body: {
      'body': body,
      if (materialId != null) 'material_id': materialId,
    });
    return GroupMessage.fromJson(Map<String, dynamic>.from(res as Map));
  }

  static Future<void> deleteMessage(int groupId, int messageId) =>
      ApiClient.request('DELETE', '/groups/$groupId/messages/$messageId');

  static Future<void> report(int groupId,
      {required String reason, int? messageId, String note = ''}) =>
      ApiClient.request('POST', '/groups/$groupId/report', body: {
        'reason': reason,
        if (messageId != null) 'message_id': messageId,
        'note': note,
      });

  /// File details of a shared material (to open it).
  static Future<Map<String, dynamic>> material(int materialId) async {
    final res = await ApiClient.request('GET', '/materials/$materialId');
    return Map<String, dynamic>.from(res as Map);
  }

  // ── Member + admin tools ─────────────────────────────────────────────────

  static Future<void> changeNickname(int groupId, String nickname) =>
      ApiClient.request('PATCH', '/groups/$groupId/me', body: {'nickname': nickname});

  static Future<List<JoinRequest>> requests(int groupId) async {
    final res = await ApiClient.request('GET', '/groups/$groupId/requests');
    return _list(res, 'requests')
        .map((e) => JoinRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> approve(int groupId, int memberId) =>
      ApiClient.request('POST', '/groups/$groupId/requests/$memberId/approve');

  static Future<void> decline(int groupId, int memberId) =>
      ApiClient.request('POST', '/groups/$groupId/requests/$memberId/decline');

  static Future<void> removeMember(int groupId, int memberId) =>
      ApiClient.request('DELETE', '/groups/$groupId/members/$memberId');

  static Future<void> transferAdmin(int groupId, int memberId) =>
      ApiClient.request('POST', '/groups/$groupId/transfer-admin',
          body: {'member_id': memberId});

  static Future<StudyGroup> update(
    int groupId, {
    required String name,
    required String description,
    required String icon,
    required String privacy,
    required int maxMembers,
    int? courseId,
  }) async {
    final res = await ApiClient.request('PATCH', '/groups/$groupId', body: {
      'name': name,
      'description': description,
      'icon': icon,
      'privacy': privacy,
      'max_members': maxMembers,
      'course_id': courseId,
    });
    return StudyGroup.fromJson(Map<String, dynamic>.from(res as Map));
  }

  static Future<String> regenerateCode(int groupId) async {
    final res = await ApiClient.request('POST', '/groups/$groupId/regenerate-code');
    return (res as Map)['join_code'] as String;
  }

  static Future<void> deleteGroup(int groupId) =>
      ApiClient.request('DELETE', '/groups/$groupId');

  // ── App admin (moderation) ───────────────────────────────────────────────

  static Future<List<GroupReport>> adminReports({String status = 'open'}) async {
    final res = await ApiClient.request('GET', '/admin/groups/reports',
        query: {'status': status, 'limit': '50'});
    return _list(res, 'reports')
        .map((e) => GroupReport.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> adminResolveReport(int reportId) =>
      ApiClient.request('POST', '/admin/groups/reports/$reportId/resolve');

  static Future<void> adminDeleteMessage(int messageId) =>
      ApiClient.request('DELETE', '/admin/groups/messages/$messageId');

  static Future<void> adminDeleteGroup(int groupId) =>
      ApiClient.request('DELETE', '/admin/groups/$groupId');
}
