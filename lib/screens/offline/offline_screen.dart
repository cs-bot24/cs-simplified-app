import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/breakpoints.dart';
import '../../models/offline_material.dart';
import '../../providers/academic_provider.dart';
import '../../providers/offline_provider.dart';
import '../../services/offline/offline_library_service.dart';
import '../../widgets/requires_internet_view.dart';
import '../browse/levels_screen.dart';
import '../pdf/pdf_viewer_screen.dart';
import 'download_queue_screen.dart';
import 'offline_settings_screen.dart';
import 'storage_management_screen.dart';

/// The Offline Library — a Kindle/Play-Books-style home for every
/// downloaded material: search, filter, sort, favorites, multi-select,
/// and a "Recently Opened" rail, all backed entirely by local data.
class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  bool _showSearch = false;
  final _searchController = TextEditingController();
  String _query = '';

  LibraryFilter _filter = LibraryFilter.all;
  LibrarySort _sortOption = LibrarySort.recentlyDownloaded;

  bool _selecting = false;
  final Set<int> _selected = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openMaterial(OfflineMaterial m) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PdfViewerScreen(
        url: m.fileUrl,
        title: m.title,
        materialId: m.materialId,
        courseCode: m.courseCode,
        categoryName: m.categoryName,
      ),
    ));
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _deleteSelected(OfflineProvider provider) async {
    final confirmed = await _confirm(
      title: 'Remove ${_selected.length} Materials?',
      message: 'They\u2019ll be removed from this device. You can re-download them anytime.',
    );
    if (confirmed && mounted) {
      await provider.removeMany(_selected.toList());
      setState(() { _selected.clear(); _selecting = false; });
    }
  }

  // Windows desktop right-click context menu (Phase 2A, Task 9): reuses the
  // exact same OfflineProvider.removeMany() call the multi-select bulk
  // delete above already uses — just with a single-element list — and the
  // same _confirm() dialog, so there is no new backend or provider
  // operation here, only a new entry point into an existing one.
  Future<void> _removeOne(OfflineMaterial m, OfflineProvider provider) async {
    final confirmed = await _confirm(
      title: 'Remove "${m.title}"?',
      message: 'It\u2019ll be removed from this device. You can re-download it anytime.',
    );
    if (confirmed && mounted) {
      await provider.removeMany([m.materialId]);
    }
  }

  Future<void> _favoriteSelected(OfflineProvider provider) async {
    for (final id in _selected) {
      await provider.toggleFavorite(id);
    }
    setState(() { _selected.clear(); _selecting = false; });
  }

  Future<void> _shareSelected(OfflineProvider provider) async {
    final paths = _selected
        .map((id) => provider.materialFor(id)?.localPath)
        .whereType<String>()
        .toList();
    if (paths.isNotEmpty) {
      await Share.shareXFiles(paths.map((p) => XFile(p)).toList());
    }
    setState(() { _selected.clear(); _selecting = false; });
  }

  Future<bool> _confirm({required String title, required String message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _browseMaterials() async {
    await requireInternet(context,
        featureName: 'Browse Materials',
        onProceed: () async {
          final academic = context.read<AcademicProvider>();
          await academic.fetchLevels();
          if (!mounted) return;
          if (academic.levels.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(academic.error ?? 'No courses available yet.')));
            return;
          }
          _showLevelPicker(academic);
        });
  }

  void _showLevelPicker(AcademicProvider academic) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Choose a Level', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ...academic.levels.map((level) => ListTile(
                leading: Text(level.emoji, style: const TextStyle(fontSize: 20)),
                title: Text(level.levelName),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => LevelsScreen(level: level)));
                },
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OfflineProvider>();
    final allDownloaded = provider.materials.where((m) => m.isDownloaded || m.hasUpdate).toList();

    var visible = allDownloaded;
    if (_query.isNotEmpty) visible = provider.search(_query).where(allDownloaded.contains).toList();
    visible = provider.filterBy(visible, _filter);
    visible = provider.sortBy(visible, _sortOption);

    final recentlyOpened = (_query.isEmpty && _filter == LibraryFilter.all)
        ? provider.recentlyOpened(limit: 8)
        : <OfflineMaterial>[];

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search course, title, or filename\u2026',
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('Offline Library'),
        actions: [
          if (_selecting)
            TextButton(
              onPressed: () => setState(() { _selecting = false; _selected.clear(); }),
              child: const Text('Cancel'),
            )
          else ...[
            IconButton(
              icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
              onPressed: () => setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) { _query = ''; _searchController.clear(); }
              }),
            ),
            IconButton(
              tooltip: 'Download Queue',
              icon: const Icon(Icons.download_for_offline_outlined),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DownloadQueueScreen())),
            ),
            IconButton(
              tooltip: 'Storage',
              icon: const Icon(Icons.pie_chart_outline_rounded),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const StorageManagementScreen())),
            ),
            IconButton(
              tooltip: 'Offline Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const OfflineSettingsScreen())),
            ),
          ],
        ],
      ),
      body: allDownloaded.isEmpty ? _buildEmptyState() : Column(children: [
        if (recentlyOpened.isNotEmpty) _RecentlyOpenedRail(materials: recentlyOpened, onTap: _openMaterial),
        _buildFilterRow(),
        _buildSortRow(visible.length),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text('No materials match this view.',
                      style: TextStyle(color: Colors.grey[500])),
                )
              : Breakpoints.centered(
                  context,
                  ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final m = visible[i];
                      return _LibraryCard(
                        material: m,
                        selecting: _selecting,
                        selected: _selected.contains(m.materialId),
                        onTap: () => _selecting ? _toggleSelect(m.materialId) : _openMaterial(m),
                        onLongPress: () => setState(() { _selecting = true; _toggleSelect(m.materialId); }),
                        onFavorite: () => provider.toggleFavorite(m.materialId),
                        onOpen: () => _openMaterial(m),
                        onRemove: () => _removeOne(m, provider),
                      );
                    },
                  ),
                ),
        ),
      ]),
      bottomNavigationBar: _selecting && _selected.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _favoriteSelected(provider),
                      icon: const Icon(Icons.star_outline_rounded, size: 18),
                      label: const Text('Favorite'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _shareSelected(provider),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Share'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _deleteSelected(provider),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text('Delete (${_selected.length})'),
                    ),
                  ),
                ]),
              ),
            )
          : null,
    );
  }

  Widget _buildFilterRow() {
    final chips = <(LibraryFilter, String)>[
      (LibraryFilter.all, 'All'),
      (LibraryFilter.recentlyOpened, 'Recently Opened'),
      (LibraryFilter.recentlyDownloaded, 'Recently Downloaded'),
      (LibraryFilter.completed, 'Completed'),
      (LibraryFilter.unread, 'Unread'),
      (LibraryFilter.favorites, 'Favorites'),
      (LibraryFilter.largeFiles, 'Large Files'),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final (value, label) = chips[i];
          final selected = _filter == value;
          return ChoiceChip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            selected: selected,
            onSelected: (_) => setState(() => _filter = value),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _buildSortRow(int count) {
    const labels = {
      LibrarySort.recentlyOpened: 'Recently Opened',
      LibrarySort.recentlyDownloaded: 'Recently Downloaded',
      LibrarySort.courseName: 'Course Name',
      LibrarySort.courseCode: 'Course Code',
      LibrarySort.fileSize: 'File Size',
      LibrarySort.readingProgress: 'Reading Progress',
      LibrarySort.alphabetical: 'Alphabetical',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(children: [
        Expanded(
          child: Text('$count material${count == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<LibrarySort>(
            value: _sortOption,
            isDense: true,
            icon: const Icon(Icons.sort_rounded, size: 16),
            items: labels.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12))))
                .toList(),
            onChanged: (v) => setState(() => _sortOption = v ?? _sortOption),
          ),
        ),
        if (!_selecting)
          TextButton(
            onPressed: () => setState(() => _selecting = true),
            child: const Text('Select', style: TextStyle(fontSize: 12)),
          ),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_library_outlined, size: 88, color: Colors.grey[200]),
          const SizedBox(height: 20),
          const Text('No offline materials yet.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            'Download PDFs from any course to study them without an internet connection.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _browseMaterials,
            icon: const Icon(Icons.explore_outlined, size: 18),
            label: const Text('Browse Materials'),
          ),
        ]),
      ),
    );
  }
}

/// Horizontal "Recently Opened" rail at the top of the library.
class _RecentlyOpenedRail extends StatelessWidget {
  final List<OfflineMaterial> materials;
  final ValueChanged<OfflineMaterial> onTap;
  const _RecentlyOpenedRail({required this.materials, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Text('Recently Opened', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
      SizedBox(
        height: 88,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: materials.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (ctx, i) {
            final m = materials[i];
            return GestureDetector(
              onTap: () => onTap(m),
              child: Container(
                width: 140,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.primary.withOpacity(0.12)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(m.timeAgo, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: m.readingProgress.clamp(0, 1),
                      minHeight: 3,
                      backgroundColor: scheme.primary.withOpacity(0.08),
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

/// The main library card: thumbnail placeholder, course info, size, pages,
/// download date, last opened, reading progress, favorite + status badges.
class _LibraryCard extends StatelessWidget {
  final OfflineMaterial material;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFavorite;
  // Phase 2A: same actions as onTap/onFavorite above, exposed separately so
  // the Windows right-click context menu can call them directly without
  // going through the mobile tap/long-press gesture semantics.
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _LibraryCard({
    required this.material,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onFavorite,
    required this.onOpen,
    required this.onRemove,
  });

  Color _accentFor(String? courseCode) {
    if (courseCode == null || courseCode.isEmpty) return const Color(0xFF6C63FF);
    final hues = [0xFF6C63FF, 0xFF00BFA5, 0xFFFF7043, 0xFF42A5F5, 0xFFAB47BC, 0xFFFFCA28];
    return Color(hues[courseCode.codeUnitAt(0) % hues.length]);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(material.courseCode);
    final progressPct = (material.readingProgress * 100).round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        // Windows desktop only (Phase 2A, Task 9): right-click opens a
        // context menu with Open / Favorite / Remove — all three call the
        // exact same callbacks the existing tap/star-icon UI already uses,
        // so this is a new entry point, not new logic. Inert everywhere
        // else (`onSecondaryTapDown` only fires from a right mouse button,
        // which Android/iOS touch and typical web interaction don't send),
        // but explicitly gated anyway for clarity and consistency with the
        // rest of this codebase's platform-gating pattern.
        onSecondaryTapDown: (details) {
          final isDesktop =
              !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
          if (!isDesktop || selecting) return;
          _showContextMenu(context, details.globalPosition);
        },
        child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : accent.withOpacity(0.15),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (selecting) ...[
            Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? accent : Colors.grey[400], size: 20),
            const SizedBox(width: 10),
          ],
          // Thumbnail placeholder — a real rendered first-page thumbnail
          // would need a PDF rasterizer; this keeps the card visually rich
          // without that extra native dependency for now.
          Container(
            width: 52, height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [accent.withOpacity(0.85), accent.withOpacity(0.55)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (material.courseCode != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                    child: Text(material.courseCode!, style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.w700)),
                  ),
                const Spacer(),
                _StatusPill(material: material),
                GestureDetector(
                  onTap: onFavorite,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      material.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 18,
                      color: material.isFavorite ? Colors.amber : Colors.grey[400],
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Text(material.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 10, runSpacing: 2, children: [
                if (material.pageCount != null) _MetaText('${material.pageCount} Pages'),
                _MetaText(material.formattedSize),
                _MetaText('Downloaded ${material.timeAgo}'),
                if (material.lastOpenedAt != null) _MetaText('Opened ${_relative(material.lastOpenedAt!)}'),
              ]),
              if (material.readingProgress > 0) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: material.readingProgress.clamp(0, 1),
                        minHeight: 4,
                        backgroundColor: accent.withOpacity(0.10),
                        valueColor: AlwaysStoppedAnimation(accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$progressPct%', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ]),
              ],
            ]),
          ),
        ]),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(value: 'open', child: Text('Open')),
        PopupMenuItem(
          value: 'favorite',
          child: Text(material.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'remove', child: Text('Remove from device')),
      ],
    ).then((choice) {
      if (choice == 'open') {
        onOpen();
      } else if (choice == 'favorite') {
        onFavorite();
      } else if (choice == 'remove') {
        onRemove();
      }
    });
  }

  static String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

class _MetaText extends StatelessWidget {
  final String text;
  const _MetaText(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(fontSize: 10.5, color: Colors.grey[500]));
}

class _StatusPill extends StatelessWidget {
  final OfflineMaterial material;
  const _StatusPill({required this.material});

  Future<void> _showUpdateOptions(BuildContext context) async {
    final provider = context.read<OfflineProvider>();
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('A newer version of "${material.title}" is available.',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: const Text('Update now'),
            onTap: () => Navigator.pop(context, 'update'),
          ),
          ListTile(
            leading: const Icon(Icons.schedule_rounded),
            title: const Text('Later'),
            subtitle: const Text('Ask me again next time'),
            onTap: () => Navigator.pop(context, 'later'),
          ),
          ListTile(
            leading: const Icon(Icons.block_rounded),
            title: const Text('Ignore this version'),
            subtitle: const Text('Don\u2019t ask again for this version'),
            onTap: () => Navigator.pop(context, 'ignore'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    switch (choice) {
      case 'update':
        await provider.applyUpdate(material.materialId);
      case 'ignore':
        await provider.ignoreUpdate(material.materialId);
      default:
      // "Later" / dismissed — no persisted change, will prompt again.
    }
  }

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    switch (material.status) {
      case OfflineStatus.updateAvailable:
        if (!material.hasUnignoredUpdate) return const SizedBox.shrink();
        label = 'Update Available'; color = Colors.amber[700]!;
      case OfflineStatus.queued:
        label = 'Queued'; color = Colors.grey;
      case OfflineStatus.downloading:
        label = 'Downloading'; color = Colors.blue;
      case OfflineStatus.paused:
        label = 'Paused'; color = Colors.orange;
      case OfflineStatus.failed:
        label = 'Failed'; color = Colors.red;
      case OfflineStatus.downloaded:
      case OfflineStatus.notDownloaded:
        return const SizedBox.shrink();
    }
    final pill = Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
      ),
    );
    if (material.status != OfflineStatus.updateAvailable) return pill;
    return GestureDetector(onTap: () => _showUpdateOptions(context), child: pill);
  }
}
