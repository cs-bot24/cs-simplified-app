import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/course_model.dart';
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
      final prov = context.read<AcademicProvider>();
      prov.fetchCategories();
      prov.fetchMaterials(widget.course.id);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.course.courseCode,
                style: const TextStyle(fontSize: 18,
                    fontWeight: FontWeight.bold)),
            if (widget.course.courseTitle.isNotEmpty)
              Text(widget.course.courseTitle,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70)),
          ],
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Category filter chips
          if (academic.categories.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  _CategoryChip(
                    label: 'All',
                    selected: _selectedCategoryId == null,
                    onTap: () {
                      setState(() => _selectedCategoryId = null);
                      academic.fetchMaterials(widget.course.id);
                    },
                  ),
                  ...academic.categories.map((cat) => _CategoryChip(
                        label: '${cat.emoji} ${cat.categoryName}',
                        selected: _selectedCategoryId == cat.id,
                        onTap: () {
                          setState(() => _selectedCategoryId = cat.id);
                          academic.fetchMaterials(widget.course.id,
                              categoryId: cat.id);
                        },
                      )),
                ],
              ),
            ),

          // Materials list
          Expanded(
            child: academic.loading
                ? const LoadingView()
                : academic.materials.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_open_outlined,
                                size: 64,
                                color: Color(AppConstants.textLightValue)),
                            SizedBox(height: 12),
                            Text('No materials uploaded yet.',
                                style: TextStyle(
                                    color: Color(AppConstants.textLightValue))),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: academic.materials.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final mat = academic.materials[i];
                          return _MaterialTile(
                            title: mat.materialTitle,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => MaterialsScreen(
                                        material: mat,
                                        courseCode:
                                            widget.course.courseCode))),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(AppConstants.primaryColorValue)
              : const Color(AppConstants.accentColorValue),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected
                    ? Colors.white
                    : const Color(AppConstants.textDarkValue))),
      ),
    );
  }
}

class _MaterialTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _MaterialTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(AppConstants.accentColorValue),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(AppConstants.primaryColorValue)
                  .withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(AppConstants.primaryColorValue)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.picture_as_pdf_outlined,
                  color: Color(AppConstants.primaryColorValue), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: Color(AppConstants.textDarkValue))),
            ),
            const Icon(Icons.download_outlined,
                size: 20, color: Color(AppConstants.primaryColorValue)),
          ],
        ),
      ),
    );
  }
}
