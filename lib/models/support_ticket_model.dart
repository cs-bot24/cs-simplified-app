import 'package:flutter/material.dart';
import '../core/storage.dart';

class SupportTicketModel {
  final int id;
  final String ticketType;
  final String title;
  final String message;
  final String status;
  final String? adminReply;
  final DateTime? repliedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? studentName;
  final String? studentEmail;

  // Local-only: has the user opened this ticket since the last admin reply?
  final bool isReplySeen;

  const SupportTicketModel({
    required this.id,
    required this.ticketType,
    required this.title,
    required this.message,
    required this.status,
    this.adminReply,
    this.repliedAt,
    required this.createdAt,
    required this.updatedAt,
    this.studentName,
    this.studentEmail,
    this.isReplySeen = true,
  });

  bool get isMaterialRequest => ticketType == 'material_request';
  bool get isSupport => ticketType == 'support';

  factory SupportTicketModel.fromJson(Map<String, dynamic> j) {
    final id          = j['id'] as int? ?? 0;
    final adminReply  = j['admin_reply'] as String?;
    final repliedAt   = j['replied_at'] != null
        ? DateTime.tryParse(j['replied_at'].toString()) : null;

    // Check local storage to see if this reply has been seen
    final seenKey    = 'reply_seen_$id';
    final seenAt     = AppStorage.getString(seenKey);
    bool isReplySeen = true;
    if (adminReply != null && adminReply.isNotEmpty) {
      if (seenAt == null) {
        isReplySeen = false; // reply exists but never been seen
      } else if (repliedAt != null) {
        // seen timestamp is before the reply was made → unseen
        final seenDt = DateTime.tryParse(seenAt);
        isReplySeen = seenDt != null && !seenDt.isBefore(repliedAt);
      }
    }

    return SupportTicketModel(
      id:           id,
      ticketType:   j['ticket_type'] as String? ?? 'support',
      title:        j['title'] as String? ?? '',
      message:      j['message'] as String? ?? '',
      status:       j['status'] as String? ?? 'open',
      adminReply:   adminReply,
      repliedAt:    repliedAt,
      createdAt:    j['created_at'] != null
          ? DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt:    j['updated_at'] != null
          ? DateTime.tryParse(j['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      studentName:  j['student_name'] as String?,
      studentEmail: j['student_email'] as String?,
      isReplySeen:  isReplySeen,
    );
  }

  /// Call this when the user opens the ticket detail screen.
  Future<void> markReplySeen() async {
    await AppStorage.setString('reply_seen_$id', DateTime.now().toIso8601String());
  }

  SupportTicketModel copyWith({
    String? status,
    String? adminReply,
    DateTime? repliedAt,
    DateTime? updatedAt,
    bool? isReplySeen,
  }) =>
      SupportTicketModel(
        id:           id,
        ticketType:   ticketType,
        title:        title,
        message:      message,
        status:       status ?? this.status,
        adminReply:   adminReply ?? this.adminReply,
        repliedAt:    repliedAt ?? this.repliedAt,
        createdAt:    createdAt,
        updatedAt:    updatedAt ?? this.updatedAt,
        studentName:  studentName,
        studentEmail: studentEmail,
        isReplySeen:  isReplySeen ?? this.isReplySeen,
      );
}

// ── Status helpers ────────────────────────────────────────────────────────────

extension SupportTicketStatusX on SupportTicketModel {
  Color get statusColor {
    if (isMaterialRequest) {
      switch (status) {
        case 'fulfilled': return Colors.green;
        case 'closed':    return Colors.red;
        default:          return Colors.orange;
      }
    } else {
      switch (status) {
        case 'under_review': return Colors.orange;
        case 'resolved':     return Colors.green;
        default:             return Colors.red;
      }
    }
  }

  String get statusLabel {
    if (isMaterialRequest) {
      switch (status) {
        case 'fulfilled': return 'FULFILLED';
        case 'closed':    return 'CLOSED';
        default:          return 'PENDING';
      }
    } else {
      switch (status) {
        case 'under_review': return 'UNDER REVIEW';
        case 'resolved':     return 'RESOLVED';
        default:             return 'OPEN';
      }
    }
  }

  String get statusEmoji {
    if (isMaterialRequest) {
      switch (status) {
        case 'fulfilled': return '🟢';
        case 'closed':    return '🔴';
        default:          return '🟡';
      }
    } else {
      switch (status) {
        case 'under_review': return '🟡';
        case 'resolved':     return '🟢';
        default:             return '🔴';
      }
    }
  }
}
