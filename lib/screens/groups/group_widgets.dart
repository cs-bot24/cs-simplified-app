// Study Groups: small shared widgets (avatar, nickname dialog).

import 'package:flutter/material.dart';

import '../../services/study_groups_api.dart';

/// Icon keys accepted by the server (keep in sync with ALLOWED_ICONS).
const Map<String, IconData> kGroupIcons = {
  'initials': Icons.abc_rounded,
  'book': Icons.menu_book_rounded,
  'brain': Icons.psychology_rounded,
  'code': Icons.code_rounded,
  'science': Icons.science_rounded,
  'rocket': Icons.rocket_launch_rounded,
  'target': Icons.track_changes_rounded,
  'idea': Icons.lightbulb_rounded,
  'chart': Icons.bar_chart_rounded,
  'palette': Icons.palette_rounded,
  'sport': Icons.sports_soccer_rounded,
  'health': Icons.favorite_rounded,
  'plant': Icons.eco_rounded,
  'crypto': Icons.currency_bitcoin_rounded,
  'camera': Icons.photo_camera_rounded,
  'music': Icons.music_note_rounded,
  'globe': Icons.public_rounded,
  'work': Icons.work_rounded,
  'school': Icons.school_rounded,
  'people': Icons.groups_rounded,
  'star': Icons.star_rounded,
};

const List<Color> _kGroupColors = [
  Color(0xFF1A3C6E),
  Color(0xFF2E7D32),
  Color(0xFF6C63FF),
  Color(0xFFC62828),
  Color(0xFF00838F),
  Color(0xFFEF6C00),
  Color(0xFF6A1B9A),
  Color(0xFF455A64),
];

Color groupColor(int id) => _kGroupColors[id.abs() % _kGroupColors.length];

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

class GroupAvatar extends StatelessWidget {
  final int id;
  final String name;
  final String icon;
  final double size;

  const GroupAvatar({
    super.key,
    required this.id,
    required this.name,
    required this.icon,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final color = groupColor(id);
    final data = kGroupIcons[icon];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: (icon == 'initials' || data == null)
          ? Text(_initials(name),
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.34))
          : Icon(data, color: color, size: size * 0.5),
    );
  }
}

/// Asks for a group nickname (pre-filled with a suggestion) and returns it,
/// or null if cancelled.
Future<String?> askNickname(
  BuildContext context, {
  required String title,
  String confirmLabel = 'Join',
}) async {
  final hint = await StudyGroupsApi.nicknameHint();
  if (!context.mounted) return null;
  final ctrl = TextEditingController(text: hint);
  String? error;
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Other members only see this nickname, never your real name.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: 'Your nickname in this group',
                errorText: error,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.length < 2) {
                setState(() => error = 'At least 2 characters');
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
  ctrl.dispose();
  return result;
}
