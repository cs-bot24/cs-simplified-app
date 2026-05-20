class CourseModel {
  final int id;
  final int semesterId;
  final String courseCode;
  final String courseTitle;
  final int sortOrder;

  CourseModel({
    required this.id,
    required this.semesterId,
    required this.courseCode,
    required this.courseTitle,
    required this.sortOrder,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) => CourseModel(
        id: json['id'],
        semesterId: json['semester_id'],
        courseCode: json['course_code'],
        courseTitle: json['course_title'] ?? '',
        sortOrder: json['sort_order'] ?? 0,
      );
}
