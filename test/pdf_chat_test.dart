// Unit tests for the PDF chat helpers.
//
// NOT RUN by the author: the Flutter/Dart SDK was not available in the
// authoring environment. Run with `flutter test test/pdf_chat_test.dart`.
import 'package:flutter_test/flutter_test.dart';
import 'package:cs_simplified/models/pdf_chat.dart';

void main() {
  group('pdfChatFromTurns', () {
    test('rebuilds question/answer bubbles in order', () {
      final out = pdfChatFromTurns([
        {'question': 'What is a stack?', 'response': 'A LIFO structure.'},
        {'question': 'And a queue?', 'response': 'FIFO.'},
      ]);
      expect(out.length, 4);
      expect(out[0].isUser, isTrue);
      expect(out[0].text, 'What is a stack?');
      expect(out[1].isUser, isFalse);
      expect(out[1].text, 'A LIFO structure.');
      expect(out[3].text, 'FIFO.');
    });

    test('quick-action prompts come back as their short labels', () {
      final out = pdfChatFromTurns([
        {'question': kPdfQuickPrompts['notes'], 'response': 'Notes...'},
      ]);
      expect(out[0].text, kPdfQuickLabels['notes']);
      expect(out[0].sent, kPdfQuickPrompts['notes']);
    });

    test('skips turns without an answer or question, and non-map items', () {
      final out = pdfChatFromTurns([
        {'question': 'Q', 'response': ''},
        {'question': '', 'response': 'A'},
        'junk',
        {'question': 'Q2', 'response': 'A2'},
      ]);
      expect(out.length, 2);
      expect(out[0].text, 'Q2');
    });

    test('empty input gives an empty chat', () {
      expect(pdfChatFromTurns([]), isEmpty);
    });
  });

  group('pdfHistoryFor', () {
    test('sends the real prompt, not the label, for quick actions', () {
      final h = pdfHistoryFor([
        PdfChatEntry(
            text: kPdfQuickLabels['explain']!,
            sent: kPdfQuickPrompts['explain'],
            isUser: true),
        const PdfChatEntry(text: 'Answer', isUser: false),
      ]);
      expect(h[0]['role'], 'user');
      expect(h[0]['content'], kPdfQuickPrompts['explain']);
      expect(h[1]['role'], 'assistant');
    });

    test('keeps only the last maxMessages and drops error bubbles', () {
      final entries = [
        for (var i = 0; i < 30; i++)
          PdfChatEntry(text: 'm$i', isUser: i.isEven),
        const PdfChatEntry(text: 'oops', isUser: false, isError: true),
      ];
      final h = pdfHistoryFor(entries, maxMessages: 10);
      expect(h.length, 10);
      expect(h.last['content'], 'm29');
      expect(h.any((m) => m['content'] == 'oops'), isFalse);
    });

    test('cuts very long messages', () {
      final h = pdfHistoryFor(
        [PdfChatEntry(text: 'x' * 5000, isUser: false)],
        maxChars: 100,
      );
      expect(h.single['content']!.length, 100);
    });

    test('empty chat gives empty history', () {
      expect(pdfHistoryFor([]), isEmpty);
    });
  });
}
