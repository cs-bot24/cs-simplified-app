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
