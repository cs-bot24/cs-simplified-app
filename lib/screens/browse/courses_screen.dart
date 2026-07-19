import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/breakpoints.dart';
import '../../models/course_model.dart';
import '../../models/material_model.dart';
import '../../models/offline_material.dart';
import '../../providers/academic_provider.dart';
import '../../providers/offline_provider.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/file_type_badge.dart';
import 'materials_screen.dart';

/// Centers [child] within a comfortable reading width on desktop, so a
/// single-column materials list doesn't stretch into a very wide, sparse
/// row on a maximized window. No-op below the desktop breakpoint — mobile
/// is completely unaffected. (Phase 2, Task 5 — see also home_screen.dart,
/// which uses the same pattern for the dashboard tab.)
Widget _desktopCentered(BuildContext context, Widget child,
    {double maxWidth = 900}) {
  if (!Breakpoints.isDesktop(context)) return child;
  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<AcademicProvider>();
      p.fetchCategories();
      await p.fetchMaterials(widget.course.id);
      _maybeSuggestOfflineDownload();
    });
  }

  /// "When user opens a course repeatedly: Suggest 'Download this course
  /// for offline study?' — only suggest once, never spam."
  Future<void> _maybeSuggestOfflineDownload() async {
    if (!mounted) return;
    final offline = context.read<OfflineProvider>();
    final academic = context.read<AcademicProvider>();
    final suggest = await offline.shouldSuggestCourseDownload(widget.course.id);
    if (!suggest || !mounted || academic.materials.isEmpty) return;
    final download = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Study offline?'),
        content: Text(
          'Download all materials in ${widget.course.courseCode} so you can '
          'study them without an internet connection.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Download')),
        ],
      ),
    );
    if (download == true && mounted) {
      final pdfs = academic.materials.where((m) => m.isPdf).toList();
      await context.read<OfflineProvider>().downloadCourse(pdfs);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a       = context.watch<AcademicProvider>();
    final offline = context.watch<OfflineProvider>();
    final scheme  = Theme.of(context).colorScheme;

    final pdfMaterials = a.materials.where((m) => m.isPdf).toList();
    final downloadedCount = offline.downloadedCountForCourse(widget.course.id);
    final allDownloaded = pdfMaterials.isNotEmpty && downloadedCount >= pdfMaterials.length;

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
      body: _desktopCentered(context, Column(children: [
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

        // Offline: bulk-download row — "12 / 15 Materials Downloaded"
        if (pdfMaterials.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Expanded(
                child: Row(children: [
                  Icon(
                    allDownloaded ? Icons.offline_pin_rounded : Icons.cloud_outlined,
                    size: 16,
                    color: allDownloaded ? Colors.green : Colors.grey[500],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    allDownloaded
                        ? 'All Materials Available Offline'
                        : '$downloadedCount / ${pdfMaterials.length} Materials Downloaded',
                    style: TextStyle(
                      fontSize: 12,
                      color: allDownloaded ? Colors.green : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ]),
              ),
              if (!allDownloaded)
                TextButton.icon(
                  onPressed: () => offline.downloadCourse(pdfMaterials),
                  icon: const Icon(Icons.download_for_offline_outlined, size: 16),
                  label: const Text('Download Entire Course', style: TextStyle(fontSize: 12)),
                ),
            ]),
          ),

        // Materials
        Expanded(
          child: a.loading ? const LoadingView()
              : (a.materials.isEmpty && a.error != null)
                  ? ErrorView(message: a.error!,
                      onRetry: () => a.fetchMaterials(widget.course.id, categoryId: _selectedCategoryId))
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
      ),
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

  IconData get _icon {
    switch (mat.fileType) {
      case 'ppt':
      case 'pptx': return Icons.slideshow_outlined;
      case 'doc':
      case 'docx': return Icons.description_outlined;
      default:     return Icons.picture_as_pdf_outlined;
    }
  }

  Color _color(ColorScheme scheme) {
    switch (mat.fileType) {
      case 'ppt':
      case 'pptx': return const Color(0xFFD04A02);
      case 'doc':
      case 'docx': return const Color(0xFF185ABD);
      default:     return scheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color  = _color(scheme);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mat.materialTitle,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                FileTypeBadge(fileType: mat.fileType),
              ],
            )),
            if (mat.isPdf) _CourseMaterialOfflineBadge(mat: mat),
            Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey[400]),
          ]),
        ),
      ),
    );
  }
}

/// Compact offline-status icon for a row in the course materials list —
/// same four states as MaterialCard's badge (not downloaded / downloading
/// / downloaded / update available).
class _CourseMaterialOfflineBadge extends StatelessWidget {
  final MaterialModel mat;
  const _CourseMaterialOfflineBadge({required this.mat});

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<OfflineProvider>();
    final status = offline.statusOf(mat.id);
    switch (status) {
      case OfflineStatus.downloaded:
        return const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Icon(Icons.offline_pin_rounded, size: 18, color: Colors.green),
        );
      case OfflineStatus.downloading:
      case OfflineStatus.queued:
      case OfflineStatus.paused:
        return const Padding(
          padding: EdgeInsets.only(right: 8),
          child: SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case OfflineStatus.updateAvailable:
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Icon(Icons.update_rounded, size: 18, color: Colors.amber[700]),
        );
      case OfflineStatus.notDownloaded:
      case OfflineStatus.failed:
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => offline.download(mat),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(Icons.cloud_download_outlined, size: 18, color: Colors.grey[400]),
          ),
        );
    }
  }
}
