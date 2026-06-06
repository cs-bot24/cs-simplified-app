import 'package:flutter/material.dart';
import '../models/material_model.dart';
import '../widgets/file_type_badge.dart';
import '../core/file_opener.dart';
import '../screens/pdf/pdf_viewer_screen.dart';

/// Reusable material card used in trending and recently-viewed sections.
///
/// Two layout variants via named constructors:
///   MaterialCard.horizontal(material: m)  — fixed-width card for horizontal scroll
///   MaterialCard.vertical(material: m)    — full-width compact row
///
/// PDF → PdfViewerScreen
/// Office docs → FileOpener.openExternal (device app)
class MaterialCard extends StatelessWidget {
  final MaterialModel material;
  final _Variant _variant;

  const MaterialCard.horizontal({super.key, required this.material})
      : _variant = _Variant.horizontal;

  const MaterialCard.vertical({super.key, required this.material})
      : _variant = _Variant.vertical;

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

  IconData get _icon {
    switch (material.fileType) {
      case 'ppt':
      case 'pptx': return Icons.slideshow_rounded;
      case 'doc':
      case 'docx': return Icons.description_rounded;
      default:     return Icons.picture_as_pdf_rounded;
    }
  }

  Color _iconColor(ColorScheme scheme) {
    switch (material.fileType) {
      case 'ppt':
      case 'pptx': return const Color(0xFFD04A02);
      case 'doc':
      case 'docx': return const Color(0xFF185ABD);
      default:     return scheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _variant == _Variant.horizontal
        ? _buildHorizontal(context)
        : _buildVertical(context);
  }

  Widget _buildHorizontal(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color  = _iconColor(scheme);

    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.primary.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color:        color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon, size: 20, color: color),
            ),
            const SizedBox(height: 8),
            FileTypeBadge(fileType: material.fileType),
            const SizedBox(height: 6),
            Text(material.materialTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, height: 1.35)),
            const Spacer(),
            if (material.courseCode != null)
              Text(material.courseCode!,
                  style: TextStyle(fontSize: 10, color: scheme.primary,
                      fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildVertical(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color  = _iconColor(scheme);

    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.primary.withOpacity(0.10)),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color:        color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(_icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  FileTypeBadge(fileType: material.fileType),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(material.materialTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ]),
                if (material.courseCode != null || material.categoryName != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    [material.courseCode, material.categoryName]
                        .whereType<String>().join(' · '),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.grey[400]),
        ]),
      ),
    );
  }
}

enum _Variant { horizontal, vertical }
