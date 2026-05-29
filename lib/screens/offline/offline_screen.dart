import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../providers/offline_provider.dart';
import '../../models/offline_material.dart';

/// The Offline tab — shows every PDF the student has downloaded.
///
/// Three states:
///   Empty    — friendly illustration + instruction
///   Filled   — header with storage used + list of materials
///   Stale    — if a file was deleted via Files app, shows
///               "File missing" with a re-download hint
///
/// Opening a file uses OpenFilex which launches the device's own
/// PDF reader — works 100% offline, no WebView or internet needed.
///
/// Deleting: swipe left to reveal the delete action, or long-press
/// for a confirmation dialog.
class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OfflineProvider>();
    final materials = provider.materials;

    return Scaffold(
      body: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        _OfflineHeader(
          count: materials.length,
          storageUsed: provider.totalStorageUsed,
        ),

        // ── Content ─────────────────────────────────────────────────────────
        Expanded(
          child: materials.isEmpty
              ? _buildEmpty(context)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: materials.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _OfflineTile(
                    material: materials[i],
                    onDelete: () => _confirmDelete(ctx, materials[i]),
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.download_for_offline_outlined,
              size: 80, color: Colors.grey[200]),
          const SizedBox(height: 20),
          const Text(
            'No Offline Materials',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'When you download a PDF it will appear here automatically. You can then open it anytime without internet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.5),
          ),
        ]),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, OfflineMaterial material) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Offline Copy?'),
        content: Text(
          '"${material.title}" will be removed from your device. You can re-download it anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<OfflineProvider>().remove(material.materialId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from offline storage'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _OfflineHeader extends StatelessWidget {
  final int count;
  final String storageUsed;

  const _OfflineHeader({required this.count, required this.storageUsed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          '📥 Offline Library',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _StatChip(
            icon: Icons.description_outlined,
            label: '$count material${count == 1 ? '' : 's'}',
          ),
          const SizedBox(width: 10),
          _StatChip(
            icon: Icons.storage_outlined,
            label: storageUsed,
          ),
        ]),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Text(label,
              style:
                  const TextStyle(color: Colors.white, fontSize: 12)),
        ]),
      );
}

// ── Individual tile ───────────────────────────────────────────────────────────

class _OfflineTile extends StatelessWidget {
  final OfflineMaterial material;
  final VoidCallback onDelete;

  const _OfflineTile({required this.material, required this.onDelete});

  Future<void> _openFile(BuildContext context) async {
    if (!material.fileExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('File not found. Please re-download.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }
    final result = await OpenFilex.open(material.filePath);
    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file: ${result.message}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileOk = material.fileExists;
    final scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key('offline_${material.materialId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white),
            SizedBox(height: 4),
            Text('Delete',
                style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // OfflineProvider.remove handles the actual removal
      },
      child: GestureDetector(
        onTap: () => _openFile(context),
        onLongPress: onDelete,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: fileOk
                  ? scheme.primary.withOpacity(0.10)
                  : Colors.red.withOpacity(0.20),
            ),
          ),
          child: Row(children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: fileOk
                    ? scheme.primary.withOpacity(0.10)
                    : Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                fileOk
                    ? Icons.picture_as_pdf_rounded
                    : Icons.broken_image_outlined,
                size: 20,
                color: fileOk ? scheme.primary : Colors.red[300],
              ),
            ),
            const SizedBox(width: 14),

            // Text block
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: fileOk ? null : Colors.red[300],
                    ),
                  ),
                  const SizedBox(height: 3),
                  fileOk
                      ? Text(
                          '${material.formattedSize}  ·  ${material.timeAgo}'
                          '${material.courseCode != null ? '  ·  ${material.courseCode}' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        )
                      : const Text(
                          'File missing — please re-download',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                          ),
                        ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            Icon(
              fileOk
                  ? Icons.open_in_new_rounded
                  : Icons.warning_amber_rounded,
              size: 16,
              color: fileOk ? Colors.grey[400] : Colors.red[300],
            ),
          ]),
        ),
      ),
    );
  }
}
