// Pure helpers for the per-PDF AI chat (saved on the server, resumed on reopen).
//
// NOT RUN by the author: the Flutter/Dart SDK was not available in the
// authoring environment. See test/pdf_chat_test.dart.

/// Prompts sent for the three quick-action buttons in the PDF AI sheet.
const Map<String, String> kPdfQuickPrompts = {
  'explain':
      'Please explain the key concepts, important definitions, and main ideas '
      'in this course material. Also include any exam tips.',
  'notes':
      'Generate structured study notes for this course material. '
      'Include: Key Concepts, Definitions, Important Points, and Exam Tips.',
  'quiz':
      'Generate 5 exam-style questions based on this course material. '
      'Mix multiple-choice and short-answer. Include correct answers.',
};

/// What the student sees in their bubble for each quick action.
const Map<String, String> kPdfQuickLabels = {
  'explain': '\u{1F4D6} Explain This Material',
  'notes':   '\u{1F4DD} Generate Notes',
  'quiz':    '❓ Quiz Me',
};

/// One bubble of a PDF chat. [sent] is the exact text that was sent to the AI
/// (differs from [text] for quick actions, which show a short label).
class PdfChatEntry {
  final String text;
  final String sent;
  final bool   isUser;
  final bool   isError;
  const PdfChatEntry({
    required this.text,
    required this.isUser,
    String? sent,
    this.isError = false,
  }) : sent = sent ?? text;
}

/// The label for a saved question, if it was one of the quick-action prompts.
String pdfDisplayForQuestion(String question) {
  for (final e in kPdfQuickPrompts.entries) {
    if (e.value == question) return kPdfQuickLabels[e.key]!;
  }
  return question;
}

/// Rebuilds the bubbles of a saved PDF chat from the server's turns
/// (oldest first). Turns without an answer are skipped.
List<PdfChatEntry> pdfChatFromTurns(List<dynamic> items) {
  final out = <PdfChatEntry>[];
  for (final raw in items) {
    if (raw is! Map) continue;
    final response = ((raw['response'] as String?) ?? '').trim();
    final question = ((raw['question'] as String?) ?? '').trim();
    if (response.isEmpty || question.isEmpty) continue;
    out.add(PdfChatEntry(
      text:   pdfDisplayForQuestion(question),
      sent:   question,
      isUser: true,
    ));
    out.add(PdfChatEntry(text: response, isUser: false));
  }
  return out;
}

/// The conversation history sent with the next question: the last
/// [maxMessages] non-error bubbles, each cut to [maxChars] characters, so the
/// request stays small while follow-ups ("explain that again") still work.
List<Map<String, String>> pdfHistoryFor(
  List<PdfChatEntry> entries, {
  int maxMessages = 10,
  int maxChars = 1500,
}) {
  final usable = entries.where((m) => !m.isError && m.sent.trim().isNotEmpty).toList();
  final window = usable.length > maxMessages
      ? usable.sublist(usable.length - maxMessages)
      : usable;
  return [
    for (final m in window)
      {
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.sent.length > maxChars ? m.sent.substring(0, maxChars) : m.sent,
      },
  ];
}
