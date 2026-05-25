import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/material_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/academic_provider.dart';
import '../pdf/pdf_viewer_screen.dart';

class MaterialsScreen extends StatelessWidget {
  final MaterialModel material;
  final String courseCode;
  const MaterialsScreen({super.key, required this.material, required this.courseCode});

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
          Center(
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.picture_as_pdf_rounded, size: 56, color: scheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(material.materialTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(courseCode, style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PdfViewerScreen(
                      url: material.fileUrl, title: material.materialTitle))),
              icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
              label: const Text('Open PDF',
                  style: TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
          ),
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
