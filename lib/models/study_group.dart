// Study Groups: data model + helpers shared by the group screens.

int _asInt(dynamic v) => v is num ? v.toInt() : 0;

class StudyGroup {
  final int id;
  final String name;
  final String description;
  final String icon;
  final String privacy; // 'public' | 'private'
  final int maxMembers;
  final int memberCount;
  final int? courseId;
  final String? courseCode;

  /// My relation to the group: 'active' | 'pending' | null (not a member).
  final String? myStatus;
  final String? myRole; // 'admin' | 'member' | null
  final String? myNickname;

  /// Push notifications muted for me (My Groups list: `muted`, detail: `my_muted`).
  final bool myMuted;

  /// Only sent to active members.
  final String? joinCode;

  final int pendingCount; // admins only
  final int unreadCount; // My Groups list only
  final String? lastMessageNickname;
  final String? lastMessageText;
  final DateTime? lastMessageAt;

  const StudyGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.privacy,
    required this.maxMembers,
    required this.memberCount,
    this.courseId,
    this.courseCode,
    this.myStatus,
    this.myRole,
    this.myNickname,
    this.myMuted = false,
    this.joinCode,
    this.pendingCount = 0,
    this.unreadCount = 0,
    this.lastMessageNickname,
    this.lastMessageText,
    this.lastMessageAt,
  });

  bool get isPrivate => privacy == 'private';
  bool get isFull => memberCount >= maxMembers;
  bool get isActive => myStatus == 'active';
  bool get isPending => myStatus == 'pending';
  bool get isAdmin => isActive && myRole == 'admin';

  /// Works for all three payloads: /groups/mine (status, role, nickname),
  /// /groups/discover (my_status) and /groups/{id} (my_status, my_role, ...).
  factory StudyGroup.fromJson(Map<String, dynamic> j) {
    return StudyGroup(
      id: _asInt(j['id']),
      name: (j['name'] ?? '') as String,
      description: (j['description'] ?? '') as String,
      icon: (j['icon'] ?? 'initials') as String,
      privacy: (j['privacy'] ?? 'public') as String,
      maxMembers: _asInt(j['max_members']),
      memberCount: _asInt(j['member_count']),
      courseId: j['course_id'] is num ? (j['course_id'] as num).toInt() : null,
      courseCode: j['course_code'] as String?,
      myStatus: (j['my_status'] ?? j['status']) as String?,
      myRole: (j['my_role'] ?? j['role']) as String?,
      myNickname: (j['my_nickname'] ?? j['nickname']) as String?,
      myMuted: (j['my_muted'] ?? j['muted']) == true,
      joinCode: j['join_code'] as String?,
      pendingCount: _asInt(j['pending_count']),
      unreadCount: _asInt(j['unread_count']),
      lastMessageNickname: j['last_message_nickname'] as String?,
      lastMessageText: j['last_message_text'] as String?,
      lastMessageAt: j['last_message_at'] is String
          ? DateTime.tryParse(j['last_message_at'] as String)?.toLocal()
          : null,
    );
  }
}

class GroupMember {
  final int id;
  final String nickname;
  final String role;
  final bool isMe;

  const GroupMember({
    required this.id,
    required this.nickname,
    required this.role,
    required this.isMe,
  });

  bool get isAdmin => role == 'admin';

  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
        id: _asInt(j['id']),
        nickname: (j['nickname'] ?? '') as String,
        role: (j['role'] ?? 'member') as String,
        isMe: j['is_me'] == true,
      );
}

/// One chat bubble. Deleted messages arrive blanked (deleted == true).
class GroupMessage {
  final int id;
  final String nickname;
  final String kind; // 'text' | 'material'
  final String body;
  final int? materialId;
  final String? materialTitle;
  final DateTime? createdAt;
  final bool deleted;
  final bool isMine;

  const GroupMessage({
    required this.id,
    required this.nickname,
    required this.kind,
    required this.body,
    this.materialId,
    this.materialTitle,
    this.createdAt,
    required this.deleted,
    required this.isMine,
  });

  bool get isMaterial => kind == 'material' && materialId != null;

  factory GroupMessage.fromJson(Map<String, dynamic> j) => GroupMessage(
        id: _asInt(j['id']),
        nickname: (j['nickname'] ?? '') as String,
        kind: (j['kind'] ?? 'text') as String,
        body: (j['body'] ?? '') as String,
        materialId:
            j['material_id'] is num ? (j['material_id'] as num).toInt() : null,
        materialTitle: j['material_title'] as String?,
        createdAt: j['created_at'] is String
            ? DateTime.tryParse(j['created_at'] as String)?.toLocal()
            : null,
        deleted: j['deleted'] == true,
        isMine: j['is_mine'] == true,
      );
}

class MessagePage {
  final List<GroupMessage> messages;
  final bool hasOlder;
  const MessagePage(this.messages, this.hasOlder);
}

class JoinRequest {
  final int id;
  final String nickname;
  const JoinRequest({required this.id, required this.nickname});

  factory JoinRequest.fromJson(Map<String, dynamic> j) =>
      JoinRequest(id: _asInt(j['id']), nickname: (j['nickname'] ?? '') as String);
}

/// A report as shown to the app admin.
class GroupReport {
  final int id;
  final String reason;
  final String note;
  final int groupId;
  final String groupName;
  final int memberCount;
  final int? messageId;
  final String? messageNickname;
  final String? messageBody;
  final bool messageDeleted;
  final String reporterName;
  final DateTime? createdAt;

  const GroupReport({
    required this.id,
    required this.reason,
    required this.note,
    required this.groupId,
    required this.groupName,
    required this.memberCount,
    this.messageId,
    this.messageNickname,
    this.messageBody,
    required this.messageDeleted,
    required this.reporterName,
    this.createdAt,
  });

  factory GroupReport.fromJson(Map<String, dynamic> j) => GroupReport(
        id: _asInt(j['id']),
        reason: (j['reason'] ?? '') as String,
        note: (j['note'] ?? '') as String,
        groupId: _asInt(j['group_id']),
        groupName: (j['group_name'] ?? '') as String,
        memberCount: _asInt(j['member_count']),
        messageId:
            j['message_id'] is num ? (j['message_id'] as num).toInt() : null,
        messageNickname: j['message_nickname'] as String?,
        messageBody: j['message_body'] as String?,
        messageDeleted: j['message_deleted'] == true,
        reporterName: (j['reporter_name'] ?? '') as String,
        createdAt: j['created_at'] is String
            ? DateTime.tryParse(j['created_at'] as String)?.toLocal()
            : null,
      );
}
