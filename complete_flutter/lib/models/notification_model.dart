class NotificationModel {
  final int id;
  final String title;
  final String body;
  final String category;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> j) => NotificationModel(
    id: j['id'] ?? 0,
    title: j['title'] ?? '',
    body: j['body'] ?? j['message'] ?? '',
    category: j['category'] ?? 'general',
    isRead: j['is_read'] ?? false,
    createdAt: j['created_at'] != null
        ? DateTime.tryParse(j['created_at']) ?? DateTime.now()
        : DateTime.now(),
  );

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
    id: id, title: title, body: body, category: category,
    isRead: isRead ?? this.isRead, createdAt: createdAt,
  );
}
