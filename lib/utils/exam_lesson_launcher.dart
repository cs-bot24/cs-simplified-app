// lib/utils/exam_lesson_launcher.dart
//
// Shared by every place a topic recommendation can be tapped (Daily Topics,
// Exam Focus Areas, Mock Exam weak-topic review, ...) so they all open the
// exact same auto-teaching AI Tutor experience.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ai_provider.dart';
import '../screens/ai/ai_tutor_screen.dart';

/// Auto-launches AI Tutor in Exam Lesson mode for [topic] — the student
/// never has to type anything, the lesson begins on its own, assuming zero
/// prior knowledge and teaching step by step (with code examples for
/// programming topics).
Future<bool?> launchExamLesson(
  BuildContext context, {
  required String topic,
  required String courseCode,
  required String courseTitle,
  int?    daysUntilExam,
  bool    isReview = false,
}) async {
  final ai = context.read<AiProvider>();

  ai.prepareExamLesson(
    topic:         topic,
    courseCode:    courseCode,
    courseTitle:   courseTitle,
    daysUntilExam: daysUntilExam,
    isReview:      isReview,
  );

  final result = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const AiTutorScreen()),
  );

  if (context.mounted) ai.endExamLesson();
  return result;
}
