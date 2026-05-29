class CourseModel {
  final int id;
  final int semesterId;
  final String courseCode;
  final String courseTitle;
  final int sortOrder;

  CourseModel({required this.id, required this.semesterId,
      required this.courseCode, required this.courseTitle, required this.sortOrder});

  factory CourseModel.fromJson(Map<String, dynamic> j) => CourseModel(
    id: j['id'], semesterId: j['semester_id'], courseCode: j['course_code'],
    courseTitle: j['course_title'] ?? '', sortOrder: j['sort_order'] ?? 0,
  );
}
