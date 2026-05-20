import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/material_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/academic_provider.dart';
import '../pdf/pdf_viewer_screen.dart';

class MaterialsScreen extends StatelessWidget {
  final MaterialModel material;
  final String courseCode;

  const MaterialsScreen({
    super.key,
    required this.material,
    required this.courseCode,
  });

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final academic = context.watch<AcademicProvider>();
    final isBookmarked = academic.isBookmarked(material.id);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.primaryColorValue),
        foregroundColor: Colors.white,
        title: Text(courseCode),
        elevation: 0,
        actions: [
          if (auth.isLoggedIn)
            IconButton(
              icon: Icon(
                isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
                color: Colors.white,
              ),
              onPressed: () =>
                  academic.toggleBookmark(material.id),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PDF icon
            Center(
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: const Color(AppConstants.accentColorValue),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    size: 56,
                    color: Color(AppConstants.primaryColorValue)),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(material.materialTitle,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: Color(AppConstants.textDarkValue))),
            const SizedBox(height: 8),
            Text(courseCode,
                style: const TextStyle(
                    color: Color(AppConstants.textLightValue))),
            const SizedBox(height: 32),

            // Open PDF button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => PdfViewerScreen(
                            url: material.fileUrl,
                            title: material.materialTitle))),
                icon: const Icon(Icons.open_in_new_rounded,
                    color: Colors.white),
                label: const Text('Open PDF',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(AppConstants.primaryColorValue),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Bookmark button
            if (auth.isLoggedIn)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => academic.toggleBookmark(material.id),
                  icon: Icon(
                    isBookmarked
                        ? Icons.bookmark_remove_outlined
                        : Icons.bookmark_add_outlined,
                    color: const Color(AppConstants.primaryColorValue),
                  ),
                  label: Text(
                    isBookmarked ? 'Remove Bookmark' : 'Save Bookmark',
                    style: const TextStyle(
                        color: Color(AppConstants.primaryColorValue),
                        fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: Color(AppConstants.primaryColorValue)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
