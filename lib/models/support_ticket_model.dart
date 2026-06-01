class SupportTicketModel {
  final int id;
  final String title;
  final String message;
  final String status; // open | under_review | resolved
  final String? adminReply;
  final DateTime? repliedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Admin view only (may be null in student context)
  final String? studentName;
  final String? studentEmail;

  const SupportTicketModel({
    required this.id,
    required this.title,
    required this.message,
    required this.status,
    this.adminReply,
    this.repliedAt,
    required this.createdAt,
    required this.updatedAt,
    this.studentName,
    this.studentEmail,
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> j) =>
      SupportTicketModel(
        id:           j['id'] as int? ?? 0,
        title:        j['title'] as String? ?? '',
        message:      j['message'] as String? ?? '',
        status:       j['status'] as String? ?? 'open',
        adminReply:   j['admin_reply'] as String?,
        repliedAt:    j['replied_at'] != null
            ? DateTime.tryParse(j['replied_at'].toString())
            : null,
        createdAt:    j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        updatedAt:    j['updated_at'] != null
            ? DateTime.tryParse(j['updated_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        studentName:  j['student_name'] as String?,
        studentEmail: j['student_email'] as String?,
      );
}
