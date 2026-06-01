class NotificationModel {
  final int id;
  final String title;
  final String body;
  /// Controls which filter tab the item appears under.
  /// Values from /notifications:  'announcement' | 'material' | 'system' | 'general'
  /// Values from /announcements:  'announcement' | 'material' | 'system'
  final String category;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> j) =>
      NotificationModel(
        id:        j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
        title:     j['title']    as String? ?? '',
        body:      (j['body']    ?? j['message'] ?? '') as String,
        // category comes from notifications table (Phase 1.5C migration).
        // Falls back to 'general' for pre-migration rows.
        category:  j['category'] as String? ?? 'general',
        isRead:    j['is_read']  as bool?   ?? false,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
    id:        id,
    title:     title,
    body:      body,
    category:  category,
    isRead:    isRead ?? this.isRead,
    createdAt: createdAt,
  );
}
