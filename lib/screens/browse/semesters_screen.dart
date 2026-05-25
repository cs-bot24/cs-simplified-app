import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        context.read<AcademicProvider>().fetchCourses(widget.semester.id));
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AcademicProvider>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.semester.semesterName)),
      body: a.loading ? const LoadingView()
          : a.courses.isEmpty
              ? const Center(child: Text('No courses available yet.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: a.courses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final c = a.courses[i];
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: scheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.book_outlined,
                              color: scheme.primary, size: 20),
                        ),
                        title: Text(c.courseCode,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: c.courseTitle.isNotEmpty
                            ? Text(c.courseTitle,
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]))
                            : null,
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () => Navigator.push(ctx, MaterialPageRoute(
                            builder: (_) => CoursesScreen(course: c))),
                      ),
                    );
                  },
                ),
    );
  }
}
