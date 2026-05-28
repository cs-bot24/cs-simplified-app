import 'package:flutter/material.dart';
import '../models/material_model.dart';
import '../screens/pdf/pdf_viewer_screen.dart';

/// Reusable material card used in trending and recently-viewed sections.
///
/// Two layout variants via named constructors:
///   MaterialCard.horizontal(material: m)  — fixed-width card for
///     horizontal scroll lists (trending section)
///   MaterialCard.vertical(material: m)    — full-width compact row for
///     vertical lists (continue reading section)
///
/// Both variants navigate directly to PdfViewerScreen on tap.
/// They do NOT navigate through Course → Materials because we already
/// have the URL and title in the MaterialModel — no extra API call needed.
class MaterialCard extends StatelessWidget {
  final MaterialModel material;
  final _Variant _variant;

  const MaterialCard.horizontal({super.key, required this.material})
      : _variant = _Variant.horizontal;

  const MaterialCard.vertical({super.key, required this.material})
      : _variant = _Variant.vertical;

  void _openPdf(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          url: material.fileUrl,
          title: material.materialTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _variant == _Variant.horizontal
        ? _buildHorizontal(context)
        : _buildVertical(context);
  }

  // ── Horizontal card (trending) ─────────────────────────────────────────────
  // Fixed width so it works inside a horizontal ListView.
  // Shows just the title and a PDF icon — no date, to keep it scannable.

  Widget _buildHorizontal(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _openPdf(context),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.primary.withOpacity(0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.picture_as_pdf_rounded,
                size: 20,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              material.materialTitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const Spacer(),
            if (material.courseCode != null)
              Text(
                material.courseCode!,
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Vertical card (continue reading) ──────────────────────────────────────
  // Full-width compact row. Shows title, optional course code, and
  // a relative time indicator ("2h ago", "Yesterday").

  Widget _buildVertical(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _openPdf(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scheme.primary.withOpacity(0.10),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.picture_as_pdf_rounded,
                size: 20,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.materialTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if (material.courseCode != null ||
                      material.categoryName != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      [
                        material.courseCode,
                        material.categoryName,
                      ].whereType<String>().join(' · '),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

enum _Variant { horizontal, vertical }
