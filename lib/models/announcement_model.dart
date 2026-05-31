class AnnouncementModel {
  final int id;
  final String title;
  final String message;
  /// Controls which notification tab this item appears under.
  /// Values: 'announcement' | 'material' | 'system'
  final String category;
  final String targetType;
  final int? targetId;
  final String createdAt;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.targetType,
    this.targetId,
    required this.createdAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> j) =>
      AnnouncementModel(
        id:         j['id'] as int,
        title:      j['title'] as String,
        message:    j['message'] as String,
        category:   j['category'] as String? ?? 'announcement',
        targetType: j['target_type'] as String? ?? 'global',
        targetId:   j['target_id'] as int?,
        createdAt:  j['created_at'] as String? ?? '',
      );

  String get targetLabel {
    switch (targetType) {
      case 'level':  return 'Level ${targetId ?? ''}';
      case 'course': return 'Course ${targetId ?? ''}';
      default:       return 'All Students';
    }
  }

  String get formattedDate {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7)   return '${diff.inDays}d ago';
      return dt.toString().split(' ').first;
    } catch (_) {
      return createdAt.split('T').first;
    }
  }
}
