class MaterialModel {
  final int id;
  final int courseId;
  final int categoryId;
  final String materialTitle;
  final String fileUrl;
  final String fileType; // pdf | ppt | pptx | doc | docx
  final bool isVisible;
  final String uploadedAt;
  final String? courseCode;
  final String? categoryName;
  final String? levelName;

  MaterialModel({
    required this.id,
    required this.courseId,
    required this.categoryId,
    required this.materialTitle,
    required this.fileUrl,
    this.fileType = 'pdf',
    required this.isVisible,
    required this.uploadedAt,
    this.courseCode,
    this.categoryName,
    this.levelName,
  });

  bool get isPdf   => fileType == 'pdf';
  bool get isPpt   => fileType == 'ppt' || fileType == 'pptx';
  bool get isDoc   => fileType == 'doc' || fileType == 'docx';
  bool get isOfficeDoc => isPpt || isDoc;

  factory MaterialModel.fromJson(Map<String, dynamic> j) => MaterialModel(
    id:            j['id'],
    courseId:      j['course_id']   ?? 0,
    categoryId:    j['category_id'] ?? 0,
    materialTitle: j['material_title'],
    fileUrl:       j['file_url'],
    fileType:      (j['file_type'] as String?)?.toLowerCase() ?? 'pdf',
    isVisible:     j['is_visible'] ?? true,
    uploadedAt:    j['uploaded_at'] ?? '',
    courseCode:    j['course_code'],
    categoryName:  j['category_name'],
    levelName:     j['level_name'],
  );

  /// Round-trips with [fromJson] — used to persist lists (e.g. bookmarks)
  /// to a local cache so they're still visible offline.
  Map<String, dynamic> toJson() => {
    'id': id,
    'course_id': courseId,
    'category_id': categoryId,
    'material_title': materialTitle,
    'file_url': fileUrl,
    'file_type': fileType,
    'is_visible': isVisible,
    'uploaded_at': uploadedAt,
    'course_code': courseCode,
    'category_name': categoryName,
    'level_name': levelName,
  };
}
