class CategoryModel {
  final int id;
  final String categoryName;
  final String emoji;

  CategoryModel({
    required this.id,
    required this.categoryName,
    required this.emoji,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'],
        categoryName: json['category_name'],
        emoji: json['emoji'] ?? '📄',
      );
}
