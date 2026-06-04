/// Represents a single FAQ item.
/// Architecture is future-ready: fromJson/toJson allow easy migration
/// to a backend-driven API without changing the UI layer.
class FaqItem {
  final int    id;
  final String category;
  final String question;
  final String answer;
  final List<String> tags; // for search matching

  const FaqItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    this.tags = const [],
  });

  factory FaqItem.fromJson(Map<String, dynamic> j) => FaqItem(
    id:       j['id'] as int,
    category: j['category'] as String,
    question: j['question'] as String,
    answer:   j['answer'] as String,
    tags:     (j['tags'] as List?)?.cast<String>() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'id':       id,
    'category': category,
    'question': question,
    'answer':   answer,
    'tags':     tags,
  };
}

/// A category group containing its FAQ items.
class FaqCategory {
  final String      category;
  final List<FaqItem> items;
  const FaqCategory({required this.category, required this.items});
}
