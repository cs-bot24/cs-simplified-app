class AiMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const AiMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class AiConversationModel {
  final int id;
  final String question;
  final String response;
  final DateTime createdAt;

  const AiConversationModel({
    required this.id,
    required this.question,
    required this.response,
    required this.createdAt,
  });

  factory AiConversationModel.fromJson(Map<String, dynamic> j) =>
      AiConversationModel(
        id: j['id'],
        question: j['question'],
        response: j['response'],
        createdAt: DateTime.parse(j['created_at']),
      );
}
