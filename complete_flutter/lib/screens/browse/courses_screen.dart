import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/course_model.dart';
import '../../models/material_model.dart';
import '../../providers/academic_provider.dart';
import '../../widgets/loading_view.dart';
import 'materials_screen.dart';

class CoursesScreen extends StatefulWidget {
  final CourseModel course;
  const CoursesScreen({super.key, required this.course});
  @override State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<AcademicProvider>();
      p.fetchCategories();
      p.fetchMaterials(widget.course.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final a      = context.watch<AcademicProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.course.courseCode,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (widget.course.courseTitle.isNotEmpty)
            Text(widget.course.courseTitle,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
      ),
      body: Column(children: [
        // Category chips
        if (a.categories.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              _Chip(label: 'All', selected: _selectedCategoryId == null,
                onTap: () {
                  setState(() => _selectedCategoryId = null);
                  a.fetchMaterials(widget.course.id);
                }),
              ...a.categories.map((cat) => _Chip(
                label: '${cat.emoji} ${cat.categoryName}',
                selected: _selectedCategoryId == cat.id,
                onTap: () {
                  setState(() => _selectedCategoryId = cat.id);
                  a.fetchMaterials(widget.course.id, categoryId: cat.id);
                },
              )),
            ]),
          ),

        // Materials
        Expanded(
          child: a.loading ? const LoadingView()
              : a.materials.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No materials uploaded yet.',
                          style: TextStyle(color: Colors.grey[500])),
                    ]))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: a.materials.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final mat = a.materials[i];
                        return _MaterialCard(
                          mat: mat,
                          courseCode: widget.course.courseCode,
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? scheme.primary : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500,
              color: selected ? Colors.white : null,
            )),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final MaterialModel mat;
  final String courseCode;
  const _MaterialCard({required this.mat, required this.courseCode});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => MaterialsScreen(material: mat, courseCode: courseCode))),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.primary.withOpacity(0.08)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.picture_as_pdf_outlined, color: scheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(mat.materialTitle,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          Icon(Icons.download_outlined, size: 20, color: scheme.primary),
        ]),
      ),
    );
  }
}
