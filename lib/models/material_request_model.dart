import 'package:flutter/material.dart';

class MaterialRequestModel {
  final int id;
  final String courseName;
  final String topic;
  final String? message;
  final String status;
  final String createdAt;
  final String? studentName;

  const MaterialRequestModel({
    required this.id,
    required this.courseName,
    required this.topic,
    this.message,
    required this.status,
    required this.createdAt,
    this.studentName,
  });

  factory MaterialRequestModel.fromJson(Map<String, dynamic> j) =>
      MaterialRequestModel(
        id: j['id'] as int,
        courseName: j['course_name'] as String,
        topic: j['topic'] as String,
        message: j['message'] as String?,
        status: j['status'] as String? ?? 'pending',
        createdAt: j['created_at'] as String? ?? '',
        studentName: j['student_name'] as String?,
      );

  Color get statusColor {
    switch (status) {
      case 'fulfilled': return Colors.green;
      case 'rejected':  return Colors.red;
      default:          return Colors.orange;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'fulfilled': return 'Fulfilled';
      case 'rejected':  return 'Rejected';
      default:          return 'Pending';
    }
  }

  String get formattedDate {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1)  return 'Just now';
      if (diff.inHours < 1)    return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      if (diff.inDays == 1)    return 'Yesterday';
      return '${diff.inDays}d ago';
    } catch (_) {
      return createdAt.split('T').first;
    }
  }
}
