import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/semester_model.dart';
import '../../providers/academic_provider.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import 'courses_screen.dart';

class SemestersScreen extends StatefulWidget {
  final SemesterModel semester;
  const SemestersScreen({super.key, required this.semester});
  @override State<SemestersScreen> createState() => _SemestersScreenState();
}

class _SemestersScreenState extends State<SemestersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademicProvider>().fetchCourses(widget.semester.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final academic = context.watch<AcademicProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.primaryColorValue),
        foregroundColor: Colors.white,
        title: Text(widget.semester.semesterName),
        elevation: 0,
      ),
      body: academic.loading
          ? const LoadingView()
          : academic.error != null
              ? ErrorView(
                  message: academic.error!,
                  onRetry: () => context
                      .read<AcademicProvider>()
                      .fetchCourses(widget.semester.id))
              : academic.courses.isEmpty
                  ? const Center(
                      child: Text('No courses available yet.',
                          style: TextStyle(
                              color: Color(AppConstants.textLightValue))))
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: academic.courses.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final course = academic.courses[i];
                        return ListTile(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      CoursesScreen(course: course))),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          tileColor:
                              const Color(AppConstants.accentColorValue),
                          leading: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: const Color(AppConstants.primaryColorValue)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.book_outlined,
                                color: Color(AppConstants.primaryColorValue),
                                size: 20),
                          ),
                          title: Text(course.courseCode,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(AppConstants.textDarkValue))),
                          subtitle: course.courseTitle.isNotEmpty
                              ? Text(course.courseTitle,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(
                                          AppConstants.textLightValue)))
                              : null,
                          trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: Color(AppConstants.textLightValue)),
                        );
                      },
                    ),
    );
  }
}
