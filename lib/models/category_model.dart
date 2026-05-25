class CategoryModel {
  final int id;
  final String categoryName;
  final String emoji;

  CategoryModel({required this.id, required this.categoryName, required this.emoji});

  factory CategoryModel.fromJson(Map<String, dynamic> j) => CategoryModel(
    id: j['id'], categoryName: j['category_name'], emoji: j['emoji'] ?? '📄',
  );
}
