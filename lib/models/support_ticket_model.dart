import 'package:flutter/material.dart';

class SupportTicketModel {
  final int id;
  final String ticketType; // 'support' | 'material_request'
  final String title;
  final String message;
  final String status;
  final String? adminReply;
  final DateTime? repliedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Admin view only
  final String? studentName;
  final String? studentEmail;

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
  });

  bool get isMaterialRequest => ticketType == 'material_request';
  bool get isSupport => ticketType == 'support';

  factory SupportTicketModel.fromJson(Map<String, dynamic> j) =>
      SupportTicketModel(
        id:          j['id'] as int? ?? 0,
        ticketType:  j['ticket_type'] as String? ?? 'support',
        title:       j['title'] as String? ?? '',
        message:     j['message'] as String? ?? '',
        status:      j['status'] as String? ?? 'open',
        adminReply:  j['admin_reply'] as String?,
        repliedAt:   j['replied_at'] != null
            ? DateTime.tryParse(j['replied_at'].toString())
            : null,
        createdAt:   j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        updatedAt:   j['updated_at'] != null
            ? DateTime.tryParse(j['updated_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        studentName:  j['student_name'] as String?,
        studentEmail: j['student_email'] as String?,
      );

  SupportTicketModel copyWith({
    String? status,
    String? adminReply,
    DateTime? repliedAt,
    DateTime? updatedAt,
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
      );
}

// ── Status helpers ────────────────────────────────────────────────────────────

extension SupportTicketStatusX on SupportTicketModel {
  Color get statusColor {
    if (isMaterialRequest) {
      switch (status) {
        case 'fulfilled': return Colors.green;
        case 'closed':    return Colors.red;
        default:          return Colors.orange; // pending
      }
    } else {
      switch (status) {
        case 'under_review': return Colors.orange;
        case 'resolved':     return Colors.green;
        default:             return Colors.red; // open
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
