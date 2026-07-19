import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/breakpoints.dart';
import '../../models/material_model.dart';
import '../../models/exam_prep_model.dart';
import '../../screens/pdf/pdf_viewer_screen.dart';
import 'course_exam_hub_screen.dart';

/// Exam Preparation Hub — Phase 4
///
/// Entry screen: groups exam materials by course and presents each course
/// as a card leading to the full CourseExamHubScreen.
///
/// Existing behaviour preserved:
/// - Still fetches materials from /exam-prep/materials (via courses endpoint
///   which returns materials grouped — same data, richer structure).
/// - PDFs are still accessible from within each course hub.
/// - If no materials exist, card doesn't show (banner logic unchanged).
class ExamPrepScreen extends StatefulWidget {
  const ExamPrepScreen({super.key});

  @override
  State<ExamPrepScreen> createState() => _ExamPrepScreenState();
}

class _ExamPrepScreenState extends State<ExamPrepScreen> {
  List<ExamCourse> _courses   = [];
  bool             _loading   = true;
  String?          _error;

  static const _kAmber = Color(0xFFD97706);

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await ApiClient.getExamPrepCourses();
      setState(() {
        _courses = raw
            .map((e) => ExamCourse.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      // Fall back to flat list from the original endpoint
      try {
        final raw = await ApiClient.getExamPrepMaterials();
        final mats = raw
            .map((e) => MaterialModel.fromJson(e as Map<String, dynamic>))
            .toList();
        // Group locally
        final Map<String, List<MaterialModel>> grouped = {};
        for (final m in mats) {
          final key = m.courseCode ?? 'General';
          grouped.putIfAbsent(key, () => []).add(m);
        }
        setState(() {
          _courses = grouped.entries.map((e) => ExamCourse(
            courseCode:    e.key,
            courseTitle:   e.key,
            materialCount: e.value.length,
            materials:     e.value,
          )).toList();
          _loading = false;
        });
      } catch (e) {
        setState(() { _error = 'Could not load materials.'; _loading = false; });
      }
    }
  }

  int get _totalMaterials =>
      _courses.fold(0, (sum, c) => sum + c.materialCount);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFB45309), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                const Text('🧠', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                const Text('Exam Preparation',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  _loading
                      ? 'Loading resources…'
                      : _courses.isEmpty
                          ? 'No resources yet'
                          : '${_courses.length} course${_courses.length == 1 ? '' : 's'} · '
                              '$_totalMaterials material${_totalMaterials == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _courses.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _fetchCourses,
                            child: Breakpoints.centered(
                              context,
                              ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _courses.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (ctx, i) =>
                                    _CourseCard(course: _courses[i]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 56, color: Colors.red),
        const SizedBox(height: 16),
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _fetchCourses,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ]),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🧠', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 16),
        const Text('No Exam Prep materials yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('The admin will upload exam preparation\nmaterials here soon.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      ]),
    ),
  );
}

// ── Course card ───────────────────────────────────────────────────────────────

class _CourseCard extends StatelessWidget {
  final ExamCourse course;
  static const _kAmber = Color(0xFFD97706);

  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CourseExamHubScreen(course: course),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kAmber.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              // Course icon
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: _kAmber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Center(
                  child: Text('📚', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.courseTitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(course.courseCode,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kAmber)),
                    const SizedBox(height: 6),
                    // Feature pills
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _Pill('📄 ${course.materialCount} materials'),
                        const _Pill('📝 Practice'),
                        const _Pill('⏱ Quiz'),
                        const _Pill('🎯 Focus'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey[400], size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill(this.label);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.07) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white60 : Colors.black54)),
    );
  }
}




