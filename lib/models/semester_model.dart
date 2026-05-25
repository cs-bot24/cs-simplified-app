class SemesterModel {
  final int id;
  final int levelId;
  final String semesterName;
  final int sortOrder;

  SemesterModel({required this.id, required this.levelId,
      required this.semesterName, required this.sortOrder});

  factory SemesterModel.fromJson(Map<String, dynamic> j) => SemesterModel(
    id: j['id'], levelId: j['level_id'],
    semesterName: j['semester_name'], sortOrder: j['sort_order'] ?? 0,
  );
}
