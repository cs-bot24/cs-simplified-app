import 'package:flutter/material.dart';

/// Compact badge showing file type with icon and label.
/// Fully dark-mode compatible — uses theme-aware colors only.
///
/// Usage:
///   FileTypeBadge(fileType: material.fileType)
///   FileTypeBadge(fileType: material.fileType, large: true)
class FileTypeBadge extends StatelessWidget {
  final String fileType;
  final bool   large;

  const FileTypeBadge({
    super.key,
    required this.fileType,
    this.large = false,
  });

  _BadgeConfig get _config {
    switch (fileType.toLowerCase()) {
      case 'ppt':
      case 'pptx':
        return _BadgeConfig(
          label:  fileType.toUpperCase(),
          emoji:  '📊',
          color:  const Color(0xFFD04A02), // PowerPoint orange
        );
      case 'doc':
      case 'docx':
        return _BadgeConfig(
          label:  fileType.toUpperCase(),
          emoji:  '📝',
          color:  const Color(0xFF185ABD), // Word blue
        );
      default: // pdf
        return _BadgeConfig(
          label:  'PDF',
          emoji:  '📕',
          color:  const Color(0xFFE53935), // PDF red
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg      = _config;
    final fontSize = large ? 11.0 : 9.0;
    final padding  = large
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 6, vertical: 2);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color:        cfg.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: cfg.color.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(cfg.emoji, style: TextStyle(fontSize: fontSize + 1)),
        const SizedBox(width: 3),
        Text(cfg.label,
            style: TextStyle(
              fontSize:   fontSize,
              fontWeight: FontWeight.bold,
              color:      cfg.color,
              letterSpacing: 0.3,
            )),
      ]),
    );
  }
}

/// Large icon for the material detail screen hero area.
class FileTypeIcon extends StatelessWidget {
  final String fileType;
  final double size;

  const FileTypeIcon({super.key, required this.fileType, this.size = 56});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color    color;

    switch (fileType.toLowerCase()) {
      case 'ppt':
      case 'pptx':
        icon  = Icons.slideshow_rounded;
        color = const Color(0xFFD04A02);
        break;
      case 'doc':
      case 'docx':
        icon  = Icons.description_rounded;
        color = const Color(0xFF185ABD);
        break;
      default:
        icon  = Icons.picture_as_pdf_rounded;
        color = const Color(0xFFE53935);
    }

    return Container(
      width:  size * 1.8,
      height: size * 1.8,
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(icon, size: size, color: color),
    );
  }
}

class _BadgeConfig {
  final String label, emoji;
  final Color  color;
  const _BadgeConfig({required this.label, required this.emoji, required this.color});
}
