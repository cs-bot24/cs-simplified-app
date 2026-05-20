class MaterialModel {
  final int id;
  final int courseId;
  final int categoryId;
  final String materialTitle;
  final String fileUrl;
  final bool isVisible;
  final String uploadedAt;
  // From search results
  final String? courseCode;
  final String? categoryName;
  final String? levelName;

  MaterialModel({
    required this.id,
    required this.courseId,
    required this.categoryId,
    required this.materialTitle,
    required this.fileUrl,
    required this.isVisible,
    required this.uploadedAt,
    this.courseCode,
    this.categoryName,
    this.levelName,
  });

  factory MaterialModel.fromJson(Map<String, dynamic> json) => MaterialModel(
        id: json['id'],
        courseId: json['course_id'] ?? 0,
        categoryId: json['category_id'] ?? 0,
        materialTitle: json['material_title'],
        fileUrl: json['file_url'],
        isVisible: json['is_visible'] ?? true,
        uploadedAt: json['uploaded_at'] ?? '',
        courseCode: json['course_code'],
        categoryName: json['category_name'],
        levelName: json['level_name'],
      );
}
