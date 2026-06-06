import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/material_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/academic_provider.dart';
import '../../providers/offline_provider.dart';
import '../../widgets/file_type_badge.dart';
import '../../core/file_opener.dart';
import '../pdf/pdf_viewer_screen.dart';

/// Material detail + open screen.
/// StatefulWidget + WidgetsBindingObserver so we can catch app-resume
/// after an Office file is opened externally and fire the study-ping.
class MaterialsScreen extends StatefulWidget {
  final MaterialModel material;
  final String        courseCode;
  const MaterialsScreen({
    super.key,
    required this.material,
    required this.courseCode,
  });
  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FileOpener.clearSession();
    super.dispose();
  }

  /// Called when app comes back to foreground (user returns from Office app).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      FileOpener.onAppResumed(context);
    }
  }

  Future<void> _open() async {
    if (widget.material.isPdf) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          url:        widget.material.fileUrl,
          title:      widget.material.materialTitle,
          materialId: widget.material.id,
        ),
      ));
    } else {
      await FileOpener.openExternal(
        context:    context,
        url:        widget.material.fileUrl,
        title:      widget.material.materialTitle,
        fileType:   widget.material.fileType,
        materialId: widget.material.id,
      );
    }
  }

  String get _openLabel {
    if (widget.material.isPdf)  return 'Open PDF';
    if (widget.material.isPpt)  return 'Open Presentation';
    return 'Open Document';
  }

  @override
  Widget build(BuildContext context) {
    final m          = widget.material;
    final auth       = context.watch<AuthProvider>();
    final academic   = context.watch<AcademicProvider>();
    final offline    = context.watch<OfflineProvider>();
    final scheme     = Theme.of(context).colorScheme;
    final isBookmark = academic.isBookmarked(m.id);
    final isDL       = offline.isDownloaded(m.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseCode),
        actions: [
          if (auth.isLoggedIn)
            IconButton(
              icon: Icon(isBookmark
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded),
              onPressed: () => academic.toggleBookmark(m.id),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Hero icon ────────────────────────────────────────────────────
          Center(child: FileTypeIcon(fileType: m.fileType, size: 56)),
          const SizedBox(height: 20),

          // ── Title ────────────────────────────────────────────────────────
          Text(m.materialTitle,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // ── Badges ───────────────────────────────────────────────────────
          Wrap(spacing: 8, runSpacing: 6, children: [
            FileTypeBadge(fileType: m.fileType, large: true),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(widget.courseCode,
                  style: TextStyle(fontSize: 11, color: scheme.primary,
                      fontWeight: FontWeight.w600)),
            ),
            if (isDL)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.download_done_rounded,
                      size: 11, color: Colors.green),
                  SizedBox(width: 4),
                  Text('Downloaded', style: TextStyle(
                      fontSize: 10, color: Colors.green,
                      fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),

          // ── Info banner for Office files ─────────────────────────────────
          if (m.isOfficeDoc) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        Colors.blue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: Colors.blue[400]),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  m.isPpt
                      ? 'Opens in PowerPoint, WPS Office, or Google Slides. '
                        'Study time is tracked automatically when you return.'
                      : 'Opens in Word, WPS Office, or Google Docs. '
                        'Study time is tracked automatically when you return.',
                  style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                )),
              ]),
            ),
          ],

          const SizedBox(height: 32),

          // ── Open button ──────────────────────────────────────────────────
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: _open,
              icon: Icon(
                m.isPdf
                    ? Icons.open_in_new_rounded
                    : Icons.launch_rounded,
                color: Colors.white,
              ),
              label: Text(_openLabel,
                  style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   16,
                      fontWeight: FontWeight.w600)),
            ),
          ),

          // ── Bookmark button ──────────────────────────────────────────────
          if (auth.isLoggedIn) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 52,
              child: OutlinedButton.icon(
                onPressed: () => academic.toggleBookmark(m.id),
                icon: Icon(isBookmark
                    ? Icons.bookmark_remove_outlined
                    : Icons.bookmark_add_outlined),
                label: Text(isBookmark
                    ? 'Remove Bookmark'
                    : 'Save Bookmark'),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
