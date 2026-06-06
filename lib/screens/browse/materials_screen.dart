import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/material_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/academic_provider.dart';
import '../../providers/offline_provider.dart';
import '../../widgets/file_type_badge.dart';
import '../../core/file_opener.dart';
import '../pdf/pdf_viewer_screen.dart';

class MaterialsScreen extends StatelessWidget {
  final MaterialModel material;
  final String courseCode;
  const MaterialsScreen({super.key, required this.material, required this.courseCode});

  Future<void> _open(BuildContext context) async {
    if (material.isPdf) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          url:        material.fileUrl,
          title:      material.materialTitle,
          materialId: material.id,
        ),
      ));
    } else {
      await FileOpener.openExternal(
        context:  context,
        url:      material.fileUrl,
        title:    material.materialTitle,
        fileType: material.fileType,
      );
    }
  }

  String get _openButtonLabel {
    if (material.isPdf)  return 'Open PDF';
    if (material.isPpt)  return 'Open with PowerPoint';
    return 'Open with Word';
  }

  @override
  Widget build(BuildContext context) {
    final auth       = context.watch<AuthProvider>();
    final academic   = context.watch<AcademicProvider>();
    final scheme     = Theme.of(context).colorScheme;
    final isBookmark = academic.isBookmarked(material.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(courseCode),
        actions: [
          if (auth.isLoggedIn)
            IconButton(
              icon: Icon(isBookmark
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded),
              onPressed: () => academic.toggleBookmark(material.id),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── File type icon ───────────────────────────────────────────────
          Center(child: FileTypeIcon(fileType: material.fileType, size: 56)),
          const SizedBox(height: 20),

          // ── Title + badges ───────────────────────────────────────────────
          Text(material.materialTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(children: [
            FileTypeBadge(fileType: material.fileType, large: true),
            const SizedBox(width: 8),
            Text(courseCode, style: TextStyle(color: Colors.grey[500])),
            if (context.watch<OfflineProvider>().isDownloaded(material.id)) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:  Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.download_done_rounded, size: 11, color: Colors.green),
                  SizedBox(width: 4),
                  Text('Downloaded', style: TextStyle(
                      fontSize: 10, color: Colors.green,
                      fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ]),

          // ── External app notice for Office docs ──────────────────────────
          if (material.isOfficeDoc) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        Colors.blue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: Colors.blue[400]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    material.isPpt
                        ? 'This file will open in PowerPoint, WPS Office, or Google Slides.'
                        : 'This file will open in Word, WPS Office, or Google Docs.',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 32),

          // ── Open button ──────────────────────────────────────────────────
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _open(context),
              icon: Icon(
                material.isPdf
                    ? Icons.open_in_new_rounded
                    : Icons.launch_rounded,
                color: Colors.white,
              ),
              label: Text(_openButtonLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
          ),

          // ── Bookmark button ──────────────────────────────────────────────
          if (auth.isLoggedIn) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 52,
              child: OutlinedButton.icon(
                onPressed: () => academic.toggleBookmark(material.id),
                icon: Icon(isBookmark
                    ? Icons.bookmark_remove_outlined
                    : Icons.bookmark_add_outlined),
                label: Text(isBookmark ? 'Remove Bookmark' : 'Save Bookmark'),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
