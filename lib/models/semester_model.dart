class SemesterModel {
  final int id;
  final int levelId;
  final String semesterName;
  final int sortOrder;

  SemesterModel({
    required this.id,
    required this.levelId,
    required this.semesterName,
    required this.sortOrder,
  });

  factory SemesterModel.fromJson(Map<String, dynamic> json) => SemesterModel(
        id: json['id'],
        levelId: json['level_id'],
        semesterName: json['semester_name'],
        sortOrder: json['sort_order'] ?? 0,
      );
}
