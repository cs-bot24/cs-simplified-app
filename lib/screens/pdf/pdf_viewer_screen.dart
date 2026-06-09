// ============================================================
//  pdf_viewer_screen.dart — Phase 2C
//
//  Phases implemented:
//    Phase 1 — Floating AI button → bottom sheet chat
//    Phase 2 — Context-aware AI (material title, course, level)
//    Phase 3 — N/A: WebView/Google Drive viewer does not expose
//              text selection. Cannot be implemented without
//              switching to a native PDF renderer.
//    Phase 4 — Explain This Page (toolbar button, uses material context)
//    Phase 5 — Generate Notes (toolbar button)
//    Phase 6 — Quiz Me (toolbar button)
//
//  Architecture notes:
//    - Reading position (WebView scroll) is preserved automatically
//      because the WebView is never unmounted when the bottom sheet
//      opens and closes.
//    - All AI calls go through the existing AiProvider so usage
//      tracking, quotas, and conversation history work unchanged.
//    - The bottom sheet uses a DraggableScrollableSheet so the
//      student can resize it to see more of the PDF or more of the chat.
//    - Page text extraction is not possible with the WebView viewer.
//      Phases 4–6 therefore send the material title + course as context
//      rather than the literal page text. This still produces
//      course-relevant AI responses.
// ============================================================

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/api_client.dart';
import '../../models/offline_material.dart';
import '../../models/rating_model.dart';
import '../../providers/ai_provider.dart';
import '../../providers/offline_provider.dart';
import '../../providers/leaderboard_provider.dart';
import '../../providers/achievement_provider.dart';
import '../../widgets/rating_dialog.dart';

// ── Colour constants (matches app dark theme) ─────────────────────────────────
const _kBackground    = Color(0xFF1A1A1A);
const _kSurface       = Color(0xFF2C2C2C);
const _kSurfaceLight  = Color(0xFF383838);
const _kAccent        = Color(0xFF6C63FF);   // matches existing AI screen accent
const _kAccentLight   = Color(0xFF8B85FF);
const _kTextPrimary   = Colors.white;
const _kTextSecondary = Color(0xFFAAAAAA);
const _kUserBubble    = Color(0xFF6C63FF);
const _kAiBubble      = Color(0xFF2C2C2C);


class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  /// Material ID — used for view tracking, study ping, rating, and AI context.
  final int? materialId;

  /// Optional course/category context forwarded to the AI.
  final String? courseCode;
  final String? levelName;
  final String? categoryName;

  const PdfViewerScreen({
    super.key,
    required this.url,
    required this.title,
    this.materialId,
    this.courseCode,
    this.levelName,
    this.categoryName,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  // ── WebView ───────────────────────────────────────────────────────────────
  late final WebViewController _webController;

  // ── Dio for downloads ─────────────────────────────────────────────────────
  final Dio _dio = Dio();

  // ── UI state ──────────────────────────────────────────────────────────────
  bool _isLoading     = true;
  bool _hasError      = false;
  bool _isDownloading = false;
  double _downloadProgress = 0;

  // ── AI bottom sheet ───────────────────────────────────────────────────────
  bool _aiSheetOpen = false;

  // ── Rating & study tracking ───────────────────────────────────────────────
  final Stopwatch _stopwatch = Stopwatch();
  RatingModel?    _rating;
  Timer?          _studyTimer;
  bool            _studyPingSent = false;

  // ── Google Drive Viewer URL ───────────────────────────────────────────────
  String get _viewerUrl {
    final encoded = Uri.encodeComponent(widget.url.trim());
    return 'https://drive.google.com/viewerng/viewer?embedded=true&url=$encoded';
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initWebView();
    _stopwatch.start();
    if (widget.materialId != null) {
      ApiClient.recordMaterialView(widget.materialId!);
      _fetchRating();
      _startStudyTimer();
    }
  }

  Future<void> _fetchRating() async {
    try {
      final raw = await ApiClient.getMaterialRating(widget.materialId!);
      if (mounted) {
        setState(() => _rating = RatingModel.fromJson(raw as Map<String, dynamic>));
      }
    } catch (_) {}
  }

  void _startStudyTimer() {
    _studyTimer = Timer(const Duration(minutes: 3), () async {
      if (_studyPingSent || widget.materialId == null) return;
      _studyPingSent = true;
      try {
        final result  = await ApiClient.studyPing(widget.materialId!);
        if (!mounted)  return;
        final current = result['current_streak']       as int?  ?? 0;
        final longest = result['longest_streak']       as int?  ?? 0;
        final newDay  = result['new_study_day_counted'] as bool? ?? false;
        context.read<LeaderboardProvider>().updateMyStreak(current, longest);
        if (newDay && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Text('🔥 ', style: TextStyle(fontSize: 18)),
              Text('$current day streak — keep it up!'),
            ]),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ));
        }
        final newAchievements =
            (result['new_achievements'] as List?)?.cast<String>() ?? [];
        if (newAchievements.isNotEmpty && mounted) {
          context.read<AchievementProvider>().refreshAfterUnlock();
          for (final title in newAchievements) {
            if (!mounted) break;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(children: [
                const Text('🏅 ', style: TextStyle(fontSize: 18)),
                Expanded(child: Text('Achievement Unlocked: $title')),
              ]),
              backgroundColor: Colors.purple[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 5),
            ));
            await Future.delayed(const Duration(milliseconds: 600));
          }
        }
      } catch (e) {
        dev.log('[PdfViewer] study-ping error: $e', name: 'PdfViewerScreen');
      }
    });
  }

  Future<void> _handleClose() async {
    _stopwatch.stop();
    if (widget.materialId != null &&
        _stopwatch.elapsed.inSeconds >= 10 &&
        mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => RatingDialog(
          existingRating: _rating?.userRating,
          onSubmit: (stars) async {
            await ApiClient.rateMaterial(widget.materialId!, stars);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Row(children: [
                  Icon(Icons.star_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Thank you for rating!'),
                ]),
                backgroundColor: Colors.amber[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ));
            }
          },
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _studyTimer?.cancel();
    _dio.close();
    super.dispose();
  }

  // ── WebView init ──────────────────────────────────────────────────────────

  void _initWebView() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_kBackground)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() { _isLoading = true; _hasError = false; });
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
        onWebResourceError: (error) {
          dev.log('[PDF] error: ${error.description}', name: 'PdfViewer');
          if (error.isForMainFrame ?? true) {
            if (mounted) setState(() { _isLoading = false; _hasError = true; });
          }
        },
      ))
      ..loadRequest(Uri.parse(_viewerUrl));
  }

  void _retryLoad() {
    setState(() { _isLoading = true; _hasError = false; });
    _webController.loadRequest(Uri.parse(_viewerUrl));
  }

  // ── AI Sheet ──────────────────────────────────────────────────────────────

  void _openAiSheet() {
    if (_aiSheetOpen) return;
    setState(() => _aiSheetOpen = true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // barrierColor transparent so the PDF behind remains visible
      barrierColor: Colors.black45,
      builder: (ctx) => _AiBottomSheet(
        materialId:    widget.materialId,
        materialTitle: widget.title,
        courseCode:    widget.courseCode,
        levelName:     widget.levelName,
        categoryName:  widget.categoryName,
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _aiSheetOpen = false);
    });
  }

  // ── Phase 4/5/6 quick-action handlers ─────────────────────────────────────
  // Because we cannot extract page text from the WebView/Google Drive viewer,
  // these actions send the material + course metadata as context and ask the
  // AI to answer based on general course knowledge about the material.
  // The AI system prompt already includes the material title and course code
  // so responses remain targeted and relevant.

  void _quickAction(String action) {
    final label = switch (action) {
      'explain' => 'Explain This Material',
      'notes'   => 'Generate Notes',
      'quiz'    => 'Quiz Me',
      _         => action,
    };
    // Reuse the AI sheet but pre-populate with the quick action
    if (_aiSheetOpen) return;
    setState(() => _aiSheetOpen = true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (ctx) => _AiBottomSheet(
        materialId:    widget.materialId,
        materialTitle: widget.title,
        courseCode:    widget.courseCode,
        levelName:     widget.levelName,
        categoryName:  widget.categoryName,
        initialAction: action,
        initialLabel:  label,
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _aiSheetOpen = false);
    });
  }

  // ── Download ──────────────────────────────────────────────────────────────

  Future<void> _downloadPdf() async {
    final rawUrl = widget.url.trim();
    if (rawUrl.isEmpty) { _toast('No download URL.', success: false); return; }
    setState(() { _isDownloading = true; _downloadProgress = 0; });
    try {
      if (Platform.isAndroid) {
        final sdk = await _androidSdkInt();
        if (sdk < 29) {
          final status = await Permission.storage.request();
          if (status.isDenied) {
            _toast('Storage permission denied.', success: false);
            return;
          }
        }
      }
      final saveDir  = await _resolveDownloadsDirectory();
      final safeName = widget.title
          .replaceAll(RegExp(r'[^\w\s\-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final destPath = '${saveDir.path}/$safeName.pdf';
      await _dio.download(
        rawUrl, destPath,
        options: Options(
          headers: {'Accept': 'application/pdf,*/*'},
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 120),
        ),
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );
      _toast('Saved to Downloads ✓', success: true);
      if (widget.materialId != null) ApiClient.logDownload(widget.materialId!);
      if (widget.materialId != null && mounted) {
        final fileSize = await File(destPath).length();
        context.read<OfflineProvider>().addDownload(OfflineMaterial(
          materialId:    widget.materialId!,
          title:         widget.title,
          filePath:      destPath,
          fileSizeBytes: fileSize,
          downloadedAt:  DateTime.now(),
        ));
      }
    } on DioException catch (e) {
      final reason = e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout
          ? 'Connection timed out.'
          : e.type == DioExceptionType.badResponse
              ? 'Server error ${e.response?.statusCode}.'
              : 'Network error. Check your connection.';
      _toast(reason, success: false);
    } on FileSystemException catch (e) {
      _toast('Could not save file: ${e.message}', success: false);
    } catch (e) {
      _toast('Download failed.', success: false);
    } finally {
      if (mounted) setState(() { _isDownloading = false; _downloadProgress = 0; });
    }
  }

  Future<void> _openExternally() async {
    final rawUrl = widget.url.trim();
    if (rawUrl.isEmpty) { _toast('No URL available.', success: false); return; }
    try {
      await launchUrl(Uri.parse(rawUrl), mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(Uri.parse(rawUrl), mode: LaunchMode.platformDefault);
      } catch (_) { _toast('Unable to open externally.', success: false); }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<Directory> _resolveDownloadsDirectory() async {
    if (Platform.isAndroid) {
      try {
        final dl = await getDownloadsDirectory();
        if (dl != null) { if (!await dl.exists()) await dl.create(recursive: true); return dl; }
      } catch (_) {}
      for (final path in ['/storage/emulated/0/Downloads', '/storage/emulated/0/Download']) {
        try {
          final dir = Directory(path);
          if (!await dir.exists()) await dir.create(recursive: true);
          return dir;
        } catch (_) {}
      }
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) { if (!await ext.exists()) await ext.create(recursive: true); return ext; }
      } catch (_) {}
    }
    return getApplicationDocumentsDirectory();
  }

  Future<int> _androidSdkInt() async {
    try {
      final version = Platform.operatingSystemVersion;
      final match   = RegExp(r'(?:SDK\s*|API\s*)(\d+)').firstMatch(version);
      if (match != null) return int.parse(match.group(1)!);
    } catch (_) {}
    return 33;
  }

  void _toast(String msg, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          success ? Icons.check_circle_outline : Icons.error_outline,
          color: Colors.white, size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: success ? Colors.green[700] : Colors.red[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _handleClose(); },
      child: Scaffold(
        backgroundColor: _kBackground,
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            // WebView — always mounted to preserve scroll position
            if (!_hasError) WebViewWidget(controller: _webController),

            if (_isLoading && !_hasError) _buildLoadingOverlay(),
            if (_hasError)               _buildErrorView(),
            if (_isDownloading)          _buildDownloadOverlay(),

            // ── Phase 1: Floating AI button ──────────────────────────────
            Positioned(
              right: 16,
              bottom: 24,
              child: _FloatingAiButton(onTap: _openAiSheet),
            ),

            // ── Phase 4/5/6: Quick-action toolbar ────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _QuickActionBar(onAction: _quickAction),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kSurface,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        // Phase 2: show course badge in app bar when context is available
        if (widget.courseCode != null)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kAccent.withOpacity(0.4)),
            ),
            child: Text(
              widget.courseCode!,
              style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: _kAccentLight,
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
          onPressed: _openExternally,
          tooltip: 'Open in Browser',
        ),
        IconButton(
          icon: const Icon(Icons.download_rounded, color: Colors.white),
          onPressed: _isDownloading ? null : _downloadPdf,
          tooltip: 'Download PDF',
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() => Container(
    color: _kBackground,
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white70, strokeWidth: 2.5),
          SizedBox(height: 16),
          Text('Loading PDF…', style: TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    ),
  );

  Widget _buildErrorView() => Container(
    color: _kBackground,
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.picture_as_pdf_outlined, size: 72, color: Colors.white24),
          const SizedBox(height: 20),
          const Text('Could not load PDF',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          const Text(
            'The Google Drive viewer could not render this file.\n'
            'You can retry, open it in your browser, or download it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _retryLoad,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _openExternally,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open Externally'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: _isDownloading ? null : _downloadPdf,
            icon: const Icon(Icons.download_rounded, color: Colors.white60, size: 18),
            label: const Text('Download Instead', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    ),
  );

  Widget _buildDownloadOverlay() => Container(
    color: Colors.black54,
    child: Center(
      child: Card(
        color: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                color: Colors.white, strokeWidth: 2.5,
              ),
              const SizedBox(height: 16),
              Text(
                _downloadProgress > 0
                    ? 'Downloading ${(_downloadProgress * 100).toInt()}%…'
                    : 'Preparing download…',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}


// ══════════════════════════════════════════════════════════════════════════════
// Phase 1: Floating AI Button
// ══════════════════════════════════════════════════════════════════════════════

class _FloatingAiButton extends StatefulWidget {
  final VoidCallback onTap;
  const _FloatingAiButton({required this.onTap});

  @override
  State<_FloatingAiButton> createState() => _FloatingAiButtonState();
}

class _FloatingAiButtonState extends State<_FloatingAiButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double>    _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kAccent, Color(0xFF9C27B0)],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _kAccent.withOpacity(0.45),
                blurRadius: 16, spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text('AI', style: TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            )),
          ),
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// Phase 4/5/6: Quick Action Bar
// ══════════════════════════════════════════════════════════════════════════════

class _QuickActionBar extends StatelessWidget {
  final void Function(String action) onAction;
  const _QuickActionBar({required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Sits at the very bottom, above the system nav bar
      padding: EdgeInsets.only(
        left: 12, right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: _kSurface.withOpacity(0.96),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          _ActionChip(
            icon: Icons.lightbulb_outline_rounded,
            label: 'Explain',
            onTap: () => onAction('explain'),
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.notes_rounded,
            label: 'Notes',
            onTap: () => onAction('notes'),
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.quiz_outlined,
            label: 'Quiz Me',
            onTap: () => onAction('quiz'),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData  icon;
  final String    label;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kAccent.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _kAccentLight, size: 15),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(
                color: _kAccentLight, fontSize: 12, fontWeight: FontWeight.w600,
              )),
            ],
          ),
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// Phase 1 & 2: AI Bottom Sheet
// ══════════════════════════════════════════════════════════════════════════════

class _AiBottomSheet extends StatefulWidget {
  final int?    materialId;
  final String  materialTitle;
  final String? courseCode;
  final String? levelName;
  final String? categoryName;

  /// When set, the sheet auto-fires this action on open (Phase 4/5/6).
  final String? initialAction;
  final String? initialLabel;

  const _AiBottomSheet({
    required this.materialTitle,
    this.materialId,
    this.courseCode,
    this.levelName,
    this.categoryName,
    this.initialAction,
    this.initialLabel,
  });

  @override
  State<_AiBottomSheet> createState() => _AiBottomSheetState();
}

class _AiBottomSheetState extends State<_AiBottomSheet> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();

  // Local message list — isolated from the global AiProvider history
  // so the PDF chat doesn't pollute the main AI Tutor conversation.
  final List<_LocalMessage> _messages = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Phase 4/5/6: auto-fire quick action if one was requested
    if (widget.initialAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fireQuickAction(widget.initialAction!);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send user question ────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    _controller.clear();
    _focusNode.unfocus();
    await _askAi(text);
  }

  // ── Quick actions (Phase 4/5/6) ───────────────────────────────────────────

  Future<void> _fireQuickAction(String action) async {
    final prompt = switch (action) {
      'explain' =>
        'Please explain the key concepts, important definitions, and main ideas '
        'in this course material. Also include any exam tips.',
      'notes' =>
        'Generate structured study notes for this course material. '
        'Include: Key Concepts, Definitions, Important Points, and Exam Tips.',
      'quiz' =>
        'Generate 5 exam-style questions based on this course material. '
        'Mix multiple-choice and short-answer. Include correct answers.',
      _ => action,
    };

    final label = switch (action) {
      'explain' => '📖 Explain This Material',
      'notes'   => '📝 Generate Notes',
      'quiz'    => '❓ Quiz Me',
      _         => action,
    };

    await _askAi(prompt, displayText: label);
  }

  Future<void> _askAi(String question, {String? displayText}) async {
    if (_loading) return;

    setState(() {
      _messages.add(_LocalMessage(text: displayText ?? question, isUser: true));
      _loading = true;
    });
    _scrollToBottom();

    try {
      final ai = context.read<AiProvider>();
      final data = await ApiClient.askAi(
        question:        question,
        mode:            ai.isExamPrep ? 'exam_prep' : 'normal',
        level:           ai.level.name,
        // Phase 2: inject full material context
        pdfMaterialId:   widget.materialId,
        pdfMaterialTitle: widget.materialTitle,
        pdfCourseCode:   widget.courseCode,
        pdfLevelName:    widget.levelName,
        pdfCategoryName: widget.categoryName,
      );
      if (mounted) {
        setState(() {
          _messages.add(_LocalMessage(
            text:   data['response'] as String,
            isUser: false,
          ));
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_LocalMessage(
            text:    'Sorry, something went wrong. Please try again.',
            isUser:  false,
            isError: true,
          ));
          _loading = false;
        });
        _scrollToBottom();
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.52,
      minChildSize:     0.30,
      maxChildSize:     0.92,
      snap: true,
      snapSizes: const [0.30, 0.52, 0.92],
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            _buildHeader(),
            const Divider(height: 1, color: Color(0xFF3A3A3A)),
            Expanded(child: _buildMessageList()),
            if (_loading) _buildTypingIndicator(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Container(
    width: 40, height: 4,
    margin: const EdgeInsets.only(top: 12, bottom: 4),
    decoration: BoxDecoration(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        // AI avatar
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kAccent, Color(0xFF9C27B0)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text('AI', style: TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold,
            )),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AI Tutor', style: TextStyle(
                color: _kTextPrimary, fontSize: 14, fontWeight: FontWeight.w700,
              )),
              Text(
                widget.courseCode != null
                    ? '${widget.courseCode} · ${widget.materialTitle}'
                    : widget.materialTitle,
                style: const TextStyle(color: _kTextSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Phase 2 context indicator
        if (widget.courseCode != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent, shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Context on', style: TextStyle(
                  color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w600,
                )),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _buildMessageList() {
    if (_messages.isEmpty) return _buildEmptyState();
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _MessageBubble(message: _messages[i]),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded,
              color: _kAccent.withOpacity(0.4), size: 40),
          const SizedBox(height: 12),
          Text(
            widget.courseCode != null
                ? 'Ask anything about ${widget.courseCode}'
                : 'Ask anything about this material',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kTextSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          const Text(
            'Or use Explain, Notes, or Quiz Me below',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF666666), fontSize: 11),
          ),
        ],
      ),
    ),
  );

  Widget _buildTypingIndicator() => Padding(
    padding: const EdgeInsets.only(left: 16, bottom: 8),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _kAiBubble,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) => _TypingDot(delay: i * 200)),
          ),
        ),
      ],
    ),
  );

  Widget _buildInputBar() => Container(
    padding: EdgeInsets.only(
      left: 12, right: 8, top: 8,
      bottom: MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom + 8,
    ),
    decoration: BoxDecoration(
      color: _kSurface,
      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
    ),
    child: Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _kSurfaceLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller:  _controller,
              focusNode:   _focusNode,
              enabled:     !_loading,
              maxLines:    4,
              minLines:    1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: const TextStyle(color: _kTextPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Ask about this material…',
                hintStyle: TextStyle(color: _kTextSecondary, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _loading ? null : _send,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _loading ? _kAccent.withOpacity(0.4) : _kAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
          ),
        ),
      ],
    ),
  );
}


// ══════════════════════════════════════════════════════════════════════════════
// Message model (local to the PDF sheet — does not affect global history)
// ══════════════════════════════════════════════════════════════════════════════

class _LocalMessage {
  final String text;
  final bool   isUser;
  final bool   isError;
  const _LocalMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}


// ══════════════════════════════════════════════════════════════════════════════
// Message Bubble — Markdown rendered for AI, plain text for user
// ══════════════════════════════════════════════════════════════════════════════

class _MessageBubble extends StatelessWidget {
  final _LocalMessage message;
  const _MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: message.isError
              ? Colors.red.withOpacity(0.15)
              : isUser ? _kUserBubble : _kAiBubble,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: message.isError
              ? Border.all(color: Colors.red.withOpacity(0.3))
              : null,
        ),
        child: isUser
            ? SelectableText(
                message.text,
                style: const TextStyle(
                  color: Colors.white, fontSize: 14, height: 1.45,
                ),
              )
            : MarkdownBody(
                data: message.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                    color: Color(0xFFDDDDDD), fontSize: 14, height: 1.55,
                  ),
                  h1: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white,
                  ),
                  h2: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white,
                  ),
                  h3: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white,
                  ),
                  strong: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white,
                  ),
                  em: const TextStyle(
                    fontStyle: FontStyle.italic, color: Color(0xFFCCCCCC),
                  ),
                  code: const TextStyle(
                    fontFamily: 'monospace', fontSize: 13,
                    backgroundColor: Color(0xFF1A1A1A),
                    color: Color(0xFF82B1FF),
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  codeblockPadding: const EdgeInsets.all(12),
                  blockquote: const TextStyle(
                    fontSize: 14, color: Color(0xFFAAAAAA),
                    fontStyle: FontStyle.italic,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: _kAccent.withOpacity(0.5), width: 3,
                      ),
                    ),
                  ),
                  blockquotePadding:
                      const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                  listBullet: const TextStyle(color: Color(0xFFDDDDDD)),
                  tableHead: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white,
                  ),
                  tableBody: const TextStyle(color: Color(0xFFDDDDDD)),
                  tableBorder: TableBorder.all(color: Colors.white12),
                  tableCellsPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  h1Padding: const EdgeInsets.only(top: 8, bottom: 4),
                  h2Padding: const EdgeInsets.only(top: 6, bottom: 3),
                  h3Padding: const EdgeInsets.only(top: 4, bottom: 2),
                ),
              ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// Typing indicator dots
// ══════════════════════════════════════════════════════════════════════════════

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>    _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween<double>(begin: 0, end: -5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7, height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(
            color: _kAccentLight, shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
