class MaterialModel {
  final int id;
  final int courseId;
  final int categoryId;
  final String materialTitle;
  final String fileUrl;
  final bool isVisible;
  final String uploadedAt;
  final String? courseCode;
  final String? categoryName;
  final String? levelName;

  MaterialModel({required this.id, required this.courseId, required this.categoryId,
      required this.materialTitle, required this.fileUrl, required this.isVisible,
      required this.uploadedAt, this.courseCode, this.categoryName, this.levelName});

  factory MaterialModel.fromJson(Map<String, dynamic> j) => MaterialModel(
    id: j['id'], courseId: j['course_id'] ?? 0, categoryId: j['category_id'] ?? 0,
    materialTitle: j['material_title'], fileUrl: j['file_url'],
    isVisible: j['is_visible'] ?? true, uploadedAt: j['uploaded_at'] ?? '',
    courseCode: j['course_code'], categoryName: j['category_name'], levelName: j['level_name'],
  );
}
