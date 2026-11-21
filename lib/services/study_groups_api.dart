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
}
