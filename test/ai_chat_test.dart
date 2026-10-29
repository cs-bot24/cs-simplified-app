// Unit tests for persistent AI Tutor chats (models + account binding).
//
// NOT RUN by the author: the Flutter/Dart SDK was not available in the
// authoring environment. Run with `flutter test test/ai_chat_test.dart`.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:cs_simplified/models/ai_model.dart';
import 'package:cs_simplified/providers/ai_provider.dart';

void main() {
  group('newClientMessageId', () {
    test('is a v4 UUID accepted by the server pattern', () {
      final id = newClientMessageId();
      expect(id.length, 36);
      expect(RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(id), isTrue);
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
          .hasMatch(id), isTrue);
    });

    test('is unique across calls and deterministic for a seeded generator', () {
      final ids = {for (var i = 0; i < 500; i++) newClientMessageId()};
      expect(ids.length, 500);
      expect(newClientMessageId(Random(1)), newClientMessageId(Random(1)));
    });
  });

  group('server models', () {
    test('AiSavedExchange expands to a question and an answer bubble', () {
      final ex = AiSavedExchange.fromJson({
        'id': 7,
        'question': 'Explain inheritance',
        'response': 'Inheritance allows…',
        'subject': 'Java',
        'mode': 'exam_prep',
        'image_used': false,
        'created_at': '2026-10-24T10:00:00+00:00',
      });
      final msgs = ex.toMessages();
      expect(msgs.length, 2);
      expect(msgs[0].isUser, isTrue);
      expect(msgs[0].text, 'Explain inheritance');
      expect(msgs[1].isUser, isFalse);
      expect(msgs[1].subject, 'Java');
      expect(msgs[1].mode, AiMode.examPrep);
      expect(msgs.every((m) => m.exchangeId == 7 && !m.failed), isTrue);
      // distinct keys for the two bubbles
      expect(msgs[0].timestamp.isBefore(msgs[1].timestamp), isTrue);
    });

    test('image exchanges get a camera prefix', () {
      final ex = AiSavedExchange.fromJson({
        'id': 1, 'question': '[image question]', 'response': 'x', 'subject': null,
        'mode': 'normal', 'image_used': true, 'created_at': '2026-10-24T10:00:00Z',
      });
      expect(ex.toMessages()[0].text, '📷 Image question');
      expect(ex.toMessages()[0].isImage, isTrue);
    });

    test('chat list page parses and tolerates missing optional fields', () {
      final page = AiChatPage.fromJson({
        'items': [
          {'id': 3, 'title': 'Java', 'last_preview': null, 'message_count': 4,
           'created_at': '2026-10-24T10:00:00Z', 'updated_at': '2026-10-24T11:00:00Z'},
        ],
        'has_more': true,
      });
      expect(page.items.single.id, 3);
      expect(page.items.single.lastPreview, isNull);
      expect(page.hasMore, isTrue);
      expect(page.items.single.copyWith(title: 'New').title, 'New');
    });

    test('chat detail parses messages oldest-first and the paging flag', () {
      final d = AiChatDetail.fromJson({
        'id': 9, 'title': 'T', 'has_more_before': true,
        'messages': [
          {'id': 1, 'question': 'a', 'response': 'b', 'subject': null, 'mode': 'normal',
           'image_used': false, 'created_at': '2026-10-24T10:00:00Z'},
          {'id': 2, 'question': 'c', 'response': 'd', 'subject': null, 'mode': 'normal',
           'image_used': false, 'created_at': '2026-10-24T10:01:00Z'},
        ],
      });
      expect(d.messages.map((m) => m.id), [1, 2]);
      expect(d.hasMoreBefore, isTrue);
    });

    test('mode name conversions round-trip', () {
      for (final m in AiMode.values) {
        expect(aiModeFromName(aiModeToName(m)), m);
      }
      expect(aiModeFromName(null), AiMode.normal);
      expect(aiModeFromName('something-else'), AiMode.normal);
    });
  });

  group('AiMessage', () {
    test('copyWith marks a message failed and can clear its client id', () {
      final m = AiMessage(
        text: 'hi', isUser: true, timestamp: DateTime(2026),
        clientMessageId: 'abc',
      );
      final failed = m.copyWith(failed: true);
      expect(failed.failed, isTrue);
      expect(failed.clientMessageId, 'abc');
      final saved = failed.copyWith(failed: false, exchangeId: 5, clearClientMessageId: true);
      expect(saved.failed, isFalse);
      expect(saved.exchangeId, 5);
      expect(saved.clientMessageId, isNull);
    });
  });

  group('AiProvider account binding', () {
    test('an Exam Lesson prepared before the first binding survives it', () {
      final ai = AiProvider();
      ai.prepareExamLesson(topic: 'Recursion', courseCode: 'COSC201', courseTitle: 'DSA');
      ai.bindUser(1);                      // null -> 1 adopts state
      expect(ai.isExamLesson, isTrue);
      expect(ai.examTopic, 'Recursion');
    });

    test('switching accounts wipes lesson state, chat state and lists', () {
      final ai = AiProvider();
      ai.bindUser(1);
      ai.prepareExamLesson(topic: 'Recursion', courseCode: 'COSC201', courseTitle: 'DSA');
      ai.bindUser(2);                      // 1 -> 2 : a different account
      expect(ai.isExamLesson, isFalse);
      expect(ai.messages, isEmpty);
      expect(ai.chatId, isNull);
      expect(ai.chats, isEmpty);
      expect(ai.hasPending, isFalse);
      expect(ai.questionsToday, 0);
    });

    test('logout (bindUser(null)) clears everything; same id is a no-op', () {
      final ai = AiProvider();
      ai.bindUser(1);
      ai.bindUser(1);
      ai.prepareExamLesson(topic: 'T', courseCode: 'C', courseTitle: 'X');
      ai.bindUser(null);
      expect(ai.isExamLesson, isFalse);
      expect(ai.chatId, isNull);
    });

    test('newChat is ignored during an Exam Lesson (the lesson is not a chat)', () {
      final ai = AiProvider();
      ai.bindUser(1);
      ai.prepareExamLesson(topic: 'T', courseCode: 'C', courseTitle: 'X');
      ai.newChat();
      expect(ai.isExamLesson, isTrue);
    });
  });
}
