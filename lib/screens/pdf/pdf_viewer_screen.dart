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

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

// Platform-conditional imports:
//   Mobile → pdf_viewer_mobile.dart  (uses dart:io, Dio, WebView, etc.)
//   Web    → pdf_viewer_web.dart     (stubs — no dart:io)
import 'pdf_viewer_mobile.dart' if (dart.library.html) 'pdf_viewer_web.dart';

// Web split-screen panels (safe on all platforms; uses kIsWeb guards internally)
import 'pdf_web_panels_stub.dart' if (dart.library.html) 'pdf_web_panels.dart';
    
import '../../core/api_client.dart';
import '../../models/material_model.dart';
import '../../models/offline_material.dart';
import '../../models/rating_model.dart';
import '../../services/pdf/i_pdf_renderer.dart';
import '../../services/pdf/pdf_renderer_service.dart';
import '../../providers/ai_provider.dart';
import '../../providers/offline_provider.dart';
import '../../providers/leaderboard_provider.dart';
import '../../providers/achievement_provider.dart';
import '../../widgets/rating_dialog.dart';
import '../../widgets/ai_message_content.dart';   // shared math+markdown renderer
import '../../widgets/ai_content_renderer.dart';  // Phase 10: unified renderer

// ── Colour constants (matches app dark theme) ─────────────────────────────────
// Brand accent — same in light and dark
const _kAccent      = Color(0xFF6C63FF);
const _kAccentLight = Color(0xFF8B85FF);
const _kUserBubble  = Color(0xFF6C63FF);

// Theme-aware helpers (call inside build methods only)
Color _kBackground(BuildContext ctx) => Theme.of(ctx).scaffoldBackgroundColor;
Color _kSurface(BuildContext ctx)    => Theme.of(ctx).cardColor;
Color _kSurfaceLight(BuildContext ctx) {
  final isDark = Theme.of(ctx).brightness == Brightness.dark;
  return isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
}
Color _kTextPrimary(BuildContext ctx)   => Theme.of(ctx).colorScheme.onSurface;
Color _kTextSecondary(BuildContext ctx) {
  final isDark = Theme.of(ctx).brightness == Brightness.dark;
  return isDark ? const Color(0xFFAAAAAA) : Colors.black54;
}
Color _kAiBubble(BuildContext ctx) {
  final isDark = Theme.of(ctx).brightness == Brightness.dark;
  return isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F4FF);
}


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
  // ── WebView (mobile only — wrapped behind conditional import) ───────────
  // WebViewControllerWrapper is defined in pdf_viewer_mobile.dart (mobile)
  // and as a no-op stub in pdf_viewer_web.dart (web).
  late final WebViewControllerWrapper _webController;

  // ── UI state ──────────────────────────────────────────────────────────────
  bool _isLoading     = true;
  bool _hasError      = false;

  // ── Offline / local-first viewing ────────────────────────────────────────
  // When non-null, a verified local copy exists and is rendered via
  // PdfRendererService — the WebView/Google-Drive-viewer path is never
  // initialised in that case, so opening a downloaded PDF never touches
  // the network (see _bootstrapViewer()).
  String? _localFilePath;
  int     _localInitialPage = 1;
  int?    _localPageCount;

  // Web-only download state (Offline Materials System is mobile-only for
  // this phase — web keeps the original browser-download behaviour).
  bool   _webIsDownloading = false;
  double _webDownloadProgress = 0;

  bool get _isDownloading => kIsWeb
      ? _webIsDownloading
      : (widget.materialId != null &&
          context.watch<OfflineProvider>().statusOf(widget.materialId!) ==
              OfflineStatus.downloading);

  double get _downloadProgress => kIsWeb
      ? _webDownloadProgress
      : (widget.materialId != null
          ? context.watch<OfflineProvider>().progressOf(widget.materialId!)
          : 0);

  // ── AI bottom sheet ───────────────────────────────────────────────────────
  bool _aiSheetOpen = false;

  // ── Web AI overlay panel state ───────────────────────────────────────────
  bool _webAiOpen = false;

  void _openWebAiPanel() {
    if (!mounted) return;
    setState(() => _webAiOpen = true);
  }

  void _closeWebAiPanel() {
    if (!mounted) return;
    setState(() => _webAiOpen = false);
  }

  // ── Study Tools panel expansion state ────────────────────────────────────
  // Shared with _StudyToolsPanel so the FAB lifts when the panel expands.
  final ValueNotifier<bool> _studyPanelExpanded = ValueNotifier(false);

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
    _stopwatch.start();
    if (widget.materialId != null) {
      ApiClient.recordMaterialView(widget.materialId!);
      _fetchRating();
      _startStudyTimer();
    }
    _bootstrapViewer();
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
    final alreadyRated = _rating?.userRating != null;
    if (widget.materialId != null &&
        !alreadyRated &&
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
              setState(() {
                _rating = (_rating ?? const RatingModel(averageRating: 0, totalRatings: 0))
                    .copyWith(userRating: stars);
              });
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
    _studyPanelExpanded.dispose();
    super.dispose();
  }

  // ── Local-first bootstrap ────────────────────────────────────────────────
  //
  // IMPORTANT RULE: if a verified local copy exists, this screen must NEVER
  // contact the backend or Google Drive to display it. `resolveLocalPath`
  // only returns a path after confirming the file exists and passes a
  // basic integrity check — no network call is made either way.
  Future<void> _bootstrapViewer() async {
    if (!kIsWeb && widget.materialId != null) {
      final offline = context.read<OfflineProvider>();
      final localPath = await offline.resolveLocalPath(widget.materialId!);
      if (localPath != null) {
        final saved = offline.materialFor(widget.materialId!)?.lastOpenedPage ?? 0;
        var startPage = 1;
        if (saved > 1 && mounted) {
          startPage = await _confirmResumePage(saved) ? saved : 1;
        }
        if (!mounted) return;
        setState(() {
          _localFilePath = localPath;
          _localInitialPage = startPage;
          _isLoading = false;
        });
        return;
      }
    }
    // No usable local copy — fall back to the existing online viewer.
    _initWebView();
  }

  /// "Continue from Page XX? Yes / No" — per the Offline Materials spec.
  Future<bool> _confirmResumePage(int page) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Continue reading?', style: TextStyle(color: Colors.white)),
        content: Text('Continue from page $page?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Start Over'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── WebView init ──────────────────────────────────────────────────────────

  void _initWebView() {
    if (kIsWeb) return;
    _webController = createWebViewController(
      _viewerUrl,
      onLoadState: (loading) {
        if (mounted) setState(() {
          _isLoading = loading;
          if (loading) _hasError = false;
        });
      },
      onError: () {
        dev.log('[PDF] WebView error', name: 'PdfViewer');
        if (mounted) setState(() { _isLoading = false; _hasError = true; });
      },
    );
  }

  void _retryLoad() {
    setState(() { _isLoading = true; _hasError = false; });
    _webController.loadUrl(_viewerUrl);
  }

  // ── AI Sheet ──────────────────────────────────────────────────────────────

  void _openAiSheet() {
    if (_aiSheetOpen) return;
    setState(() => _aiSheetOpen = true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      useSafeArea: false,
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
    // Open AI sheet with the quick action pre-fired.
    // Study Tools panel auto-collapses before calling this, so
    // _aiSheetOpen guard is the only thing we need.
    if (_aiSheetOpen) return;
    setState(() => _aiSheetOpen = true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      // useSafeArea keeps the sheet above system bars on all devices
      useSafeArea: false,
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
    if (kIsWeb) {
      // Web keeps the original "save via browser download" flow — the
      // Offline Materials System (local DB + local PDF renderer) targets
      // mobile for this phase; see pdf_viewer_web.dart.
      setState(() { _webIsDownloading = true; _webDownloadProgress = 0; });
      try {
        await downloadPdf(
          url:   widget.url,
          title: widget.title,
          onProgress: (p) {
            if (mounted) setState(() => _webDownloadProgress = p);
          },
          onToast: (msg, {required bool success}) =>
              _toast(msg, success: success),
          onSaved: (_) async {
            if (widget.materialId != null) ApiClient.logDownload(widget.materialId!);
          },
        );
      } finally {
        if (mounted) setState(() { _webIsDownloading = false; _webDownloadProgress = 0; });
      }
      return;
    }

    if (widget.materialId == null) {
      _toast('This file cannot be saved for offline use.', success: false);
      return;
    }
    final offline = context.read<OfflineProvider>();
    if (offline.isDownloaded(widget.materialId!)) return;

    // DownloadManager runs the actual transfer in the background — the
    // app bar icon and overlay below react automatically via the
    // OfflineProvider ChangeNotifier, so no manual progress plumbing here.
    await offline.download(MaterialModel(
      id:            widget.materialId!,
      courseId:      0, // Unknown from this entry point; MaterialCard's
                         // download button (which has full course context)
                         // is the primary path for course-level counts.
      categoryId:    0,
      materialTitle: widget.title,
      fileUrl:       widget.url,
      fileType:      'pdf',
      isVisible:     true,
      uploadedAt:    '',
      courseCode:    widget.courseCode,
      categoryName:  widget.categoryName,
    ));
    ApiClient.logDownload(widget.materialId!);
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
        backgroundColor: _kBackground(context),
        appBar: _buildAppBar(),
        body: kIsWeb ? _buildWebLayout() : _buildMobileLayout(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kSurface(context),
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
        _buildDownloadAction(),
      ],
    );
  }

  Widget _buildDownloadAction() {
    if (kIsWeb || widget.materialId == null) {
      return IconButton(
        icon: const Icon(Icons.download_rounded, color: Colors.white),
        onPressed: _isDownloading ? null : _downloadPdf,
        tooltip: 'Download PDF',
      );
    }
    final status = context.watch<OfflineProvider>().statusOf(widget.materialId!);
    switch (status) {
      case OfflineStatus.downloaded:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Icon(Icons.offline_pin_rounded, color: Colors.greenAccent),
        );
      case OfflineStatus.downloading:
      case OfflineStatus.queued:
      case OfflineStatus.paused:
        return const Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
          ),
        );
      case OfflineStatus.updateAvailable:
        return IconButton(
          icon: const Icon(Icons.update_rounded, color: Colors.amberAccent),
          onPressed: _downloadPdf,
          tooltip: 'Update available',
        );
      case OfflineStatus.notDownloaded:
      case OfflineStatus.failed:
        return IconButton(
          icon: const Icon(Icons.download_rounded, color: Colors.white),
          onPressed: _downloadPdf,
          tooltip: 'Save for offline use',
        );
    }
  }

  // ── Web layout: full-width PDF, AI available on demand ──────────────────
  Widget _buildWebLayout() {
    // FAB footprint reserved as a "hole" in the iframe so that the iframe
    // (a real DOM element via HtmlElementView) cannot intercept clicks
    // meant for the Flutter-rendered floating AI button on top of it.
    const double fabSize = 56;
    const double fabMargin = 16;
    final double reservedWidth  = fabSize + fabMargin * 2;
    final double reservedHeight = fabSize + fabMargin * 2;

    final width = MediaQuery.of(context).size.width;
    final double aiPanelWidth = _webAiPanelWidth(width);

    // When the AI panel/backdrop is open, also shrink the iframe's right
    // edge by the panel width so it can't intercept clicks on the panel
    // or backdrop (same HtmlElementView click-through issue as the FAB).
    final double iframeRight  = _webAiOpen ? aiPanelWidth : reservedWidth;
    final double iframeBottom = _webAiOpen ? 0 : reservedHeight;

    return Stack(
      children: [
        // PDF fills the screen except for a reserved area (see above).
        Positioned.fill(
          right: iframeRight,
          bottom: iframeBottom,
          child: WebPdfPanel(url: widget.url, title: widget.title),
        ),
        // Fill the reserved area with a plain background so there's
        // no visual gap.
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: iframeRight,
          child: Container(color: _kBackground(context)),
        ),
        if (!_webAiOpen)
          Positioned(
            right: iframeRight,
            bottom: 0,
            width: MediaQuery.of(context).size.width - iframeRight,
            height: reservedHeight,
            child: Container(color: _kBackground(context)),
          ),

        // Floating AI button (mirrors Android FAB)
        Positioned(
          right: 16,
          bottom: 16,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: _webAiOpen ? 0.0 : 1.0,
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _webAiOpen ? 0.0 : 1.0,
              child: _FloatingAiButton(onTap: _openWebAiPanel),
            ),
          ),
        ),

        // Backdrop (dims the PDF when the AI panel is open)
        if (_webAiOpen)
          Positioned.fill(
            right: aiPanelWidth,
            child: GestureDetector(
              onTap: _closeWebAiPanel,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _webAiOpen ? 1.0 : 0.0,
                curve: Curves.easeOut,
                child: Container(color: Colors.black54),
              ),
            ),
          ),

        // AI panel — responsive: right drawer / wide drawer / full-screen
        _buildWebAiOverlay(),
      ],
    );
  }

  // Desktop: right-side drawer. Tablet: wider drawer. Mobile: full-screen.
  double _webAiPanelWidth(double screenWidth) {
    if (screenWidth >= 900) return 420;
    if (screenWidth >= 600) return screenWidth * 0.7;
    return screenWidth;
  }

  Widget _buildWebAiOverlay() {
    final width = MediaQuery.of(context).size.width;
    final double panelWidth = _webAiPanelWidth(width);

    final aiPanel = Material(
      elevation: 16,
      color: Colors.transparent,
      child: SizedBox(
        width: panelWidth,
        height: double.infinity,
        child: WebAiPanel(
          materialId:    widget.materialId,
          materialTitle: widget.title,
          courseCode:    widget.courseCode,
          levelName:     widget.levelName,
          categoryName:  widget.categoryName,
          onClose:       _closeWebAiPanel,
        ),
      ),
    );

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      top: 0,
      bottom: 0,
      right: _webAiOpen ? 0 : -panelWidth,
      width: panelWidth,
      child: aiPanel,
    );
  }

  // ── Mobile layout: WebView (online) or local renderer (offline) ──────────
  Widget _buildMobileLayout() {
    return Stack(
      children: [
        if (_localFilePath != null)
          Positioned.fill(
            bottom: MediaQuery.of(context).padding.bottom + 52,
            // 100% local: no network, no auth, no server request — this is
            // the "IMPORTANT RULE" from the Offline Materials spec.
            child: PdfRendererService.instance.open(
              filePath: _localFilePath!,
              callbacks: PdfViewerCallbacks(
                initialPage: _localInitialPage,
                onDocumentLoaded: (count) => _localPageCount = count,
                onPageChanged: (page) {
                  if (widget.materialId != null) {
                    context.read<OfflineProvider>().recordProgress(
                          widget.materialId!,
                          page: page,
                          pageCount: _localPageCount,
                        );
                  }
                },
                onLoadFailed: () {
                  // Local render failed (corrupt/unsupported file) — fall
                  // back to the online viewer rather than a dead end.
                  if (mounted) {
                    setState(() { _localFilePath = null; _isLoading = true; });
                    _initWebView();
                  }
                },
              ),
            ),
          )
        else if (!_hasError)
          Positioned.fill(
            bottom: MediaQuery.of(context).padding.bottom + 52,
            child: buildWebViewWidget(_webController),
          ),
        if (_localFilePath == null && _isLoading && !_hasError) _buildLoadingOverlay(),
        if (_localFilePath == null && _hasError)               _buildErrorView(),
        if (_isDownloading)          _buildDownloadOverlay(),
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: _StudyToolsPanel(
            onAction: _quickAction,
            expandedNotifier: _studyPanelExpanded,
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _studyPanelExpanded,
          builder: (_, expanded, __) {
            final bottomPad = MediaQuery.of(context).padding.bottom;
            final fabBottom = expanded
                ? bottomPad + 140.0
                : bottomPad + 56.0;
            return AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              right: 16,
              bottom: fabBottom,
              child: _FloatingAiButton(onTap: _openAiSheet),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() => Container(
    color: _kBackground(context),
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
    color: _kBackground(context),
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
        color: _kSurface(context),
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
// Phase 4/5/6: Collapsible Study Tools Panel
// ══════════════════════════════════════════════════════════════════════════════
//
// Collapsed state: a small pill "Study Tools ⌃" sits at the bottom edge.
// Expanded state: slides up to reveal Explain / Notes / Quiz Me buttons.
// The floating AI FAB is positioned above this pill so they never overlap.

class _StudyToolsPanel extends StatefulWidget {
  final void Function(String action) onAction;
  final ValueNotifier<bool> expandedNotifier;

  const _StudyToolsPanel({
    required this.onAction,
    required this.expandedNotifier,
  });

  @override
  State<_StudyToolsPanel> createState() => _StudyToolsPanelState();
}

class _StudyToolsPanelState extends State<_StudyToolsPanel>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double>    _slideAnim;
  late final Animation<double>    _fadeAnim;
  late final Animation<double>    _chevronAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260),
    );
    _slideAnim   = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _fadeAnim    = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _chevronAnim = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    // Notify parent so the FAB can reposition itself
    widget.expandedNotifier.value = _expanded;
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  void _fireAction(String action) {
    // Auto-collapse after firing so the PDF regains full screen
    if (_expanded) _toggle();
    widget.onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Expanded button row (slides in from below) ───────────────────
        SizeTransition(
          sizeFactor: _slideAnim,
          axisAlignment: -1,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              color: _kSurface(context).withOpacity(0.97),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  _StudyChip(
                    icon: Icons.lightbulb_outline_rounded,
                    label: 'Explain',
                    onTap: () => _fireAction('explain'),
                  ),
                  const SizedBox(width: 8),
                  _StudyChip(
                    icon: Icons.notes_rounded,
                    label: 'Notes',
                    onTap: () => _fireAction('notes'),
                  ),
                  const SizedBox(width: 8),
                  _StudyChip(
                    icon: Icons.quiz_outlined,
                    label: 'Quiz Me',
                    onTap: () => _fireAction('quiz'),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Collapsed pill (always visible) ──────────────────────────────
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: 0,
              bottom: bottomPad > 0 ? bottomPad : 8,
            ),
            decoration: BoxDecoration(
              color: _kSurface(context),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.10)),
              ),
            ),
            child: Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kAccent.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_rounded,
                        color: _kAccentLight, size: 14),
                    const SizedBox(width: 6),
                    const Text(
                      'Study Tools',
                      style: TextStyle(
                        color: _kAccentLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    RotationTransition(
                      turns: _chevronAnim,
                      child: const Icon(Icons.keyboard_arrow_up_rounded,
                          color: _kAccentLight, size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StudyChip extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  const _StudyChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kAccent.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _kAccentLight, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: _kAccentLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
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

  // Scroll-intent guard — never fight the user's finger.
  bool _userScrolledUp = false;
  bool _hasNewMessage  = false;
  static const _kScrollThreshold = 80.0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    // Phase 4/5/6: auto-fire quick action if one was requested
    if (widget.initialAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fireQuickAction(widget.initialAction!);
      });
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final nearBottom = _scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - _kScrollThreshold;
    if (nearBottom && _userScrolledUp) {
      setState(() {
        _userScrolledUp = false;
        _hasNewMessage  = false; // back at bottom — clear badge
      });
    } else if (!nearBottom && !_userScrolledUp) {
      setState(() => _userScrolledUp = true);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _controller.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool force = false}) {
    if (_userScrolledUp && !force) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
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
    // The user just asked something — jump to the bottom for their own
    // outgoing message, same as the other chat screens.
    setState(() {
      _userScrolledUp = false;
      _hasNewMessage  = false;
    });
    _scrollToBottom(force: true);

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
          // The user may have scrolled up while waiting for this reply —
          // don't yank them down, just flag that something new arrived.
          if (_userScrolledUp) _hasNewMessage = true;
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
          if (_userScrolledUp) _hasNewMessage = true;
        });
        _scrollToBottom();
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // keyboardInset: how many pixels the keyboard is covering
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      // Lift the entire sheet by the keyboard height so the input
      // is always visible — smooth 200ms transition matches keyboard animation
      padding: EdgeInsets.only(bottom: keyboardInset),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: DraggableScrollableSheet(
        initialChildSize: 0.52,
        minChildSize:     0.30,
        maxChildSize:     0.92,
        snap: true,
        snapSizes: const [0.30, 0.52, 0.92],
        builder: (ctx, scrollController) => Container(
          decoration: BoxDecoration(
            color: _kSurface(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(),
              const Divider(height: 1, color: Color(0xFF3A3A3A)),
              Expanded(
                child: Stack(
                  children: [
                    _buildMessageList(scrollController),
                    if (_userScrolledUp)
                      Positioned(
                        right: 12,
                        bottom: 10,
                        child: _hasNewMessage
                            ? _SheetNewMessagePill(
                                onTap: () {
                                  setState(() {
                                    _userScrolledUp = false;
                                    _hasNewMessage  = false;
                                  });
                                  _scrollToBottom(force: true);
                                },
                              )
                            : _SheetScrollToBottomButton(
                                onTap: () {
                                  setState(() => _userScrolledUp = false);
                                  _scrollToBottom(force: true);
                                },
                              ),
                      ),
                  ],
                ),
              ),
              if (_loading) _buildTypingIndicator(),
              _buildInputBar(),
            ],
          ),
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
              Text('AI Tutor', style: TextStyle(
                color: _kTextPrimary(context), fontSize: 14, fontWeight: FontWeight.w700,
              )),
              Text(
                widget.courseCode != null
                    ? '${widget.courseCode} · ${widget.materialTitle}'
                    : widget.materialTitle,
                style: TextStyle(color: _kTextSecondary(context), fontSize: 11),
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

  Widget _buildMessageList([ScrollController? sheetScrollCtrl]) {
    if (_messages.isEmpty) return _buildEmptyState();
    return ListView.builder(
      // Use the sheet's scroll controller when available so dragging
      // the message list also controls the sheet size — natural feel.
      controller: _messages.length > 3 ? _scrollCtrl : (sheetScrollCtrl ?? _scrollCtrl),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // Swipe down on the message list dismisses the keyboard
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _messages.length,
      itemBuilder: (_, i) => RepaintBoundary(
        child: _MessageBubble(message: _messages[i]),
      ),
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
            style: TextStyle(color: _kTextSecondary(context), fontSize: 13),
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
            color: _kAiBubble(context),
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
    // No viewInsets needed here — AnimatedPadding on the sheet already
    // lifts the entire panel above the keyboard.
    padding: const EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 10),
    decoration: BoxDecoration(
      color: _kSurface(context),
      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
    ),
    child: Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _kSurfaceLight(context),
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
              style: TextStyle(color: _kTextPrimary(context), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ask about this material…',
                hintStyle: TextStyle(color: _kTextSecondary(context), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
// Scroll-to-bottom affordances (mirrors AiTutorScreen / AiLecturerScreen /
// WebAiPanel — same "↓ New Message" pattern, kept local to this file since
// the bottom sheet's color helpers differ slightly from the other screens).
// ══════════════════════════════════════════════════════════════════════════════

class _SheetScrollToBottomButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SheetScrollToBottomButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kAccent,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _SheetNewMessagePill extends StatelessWidget {
  final VoidCallback onTap;
  const _SheetNewMessagePill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kAccent,
      borderRadius: BorderRadius.circular(18),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 13),
              SizedBox(width: 5),
              Text(
                'New Message',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
// Message Bubble — uses AiMessageContent for AI messages (same pipeline as
// AI Tutor, AI Lecturer, and Exam Hub — math, Mermaid, Markdown all render).
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
              : isUser ? _kUserBubble : _kAiBubble(context),
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
        // ── User bubble: plain selectable text ───────────────────────────
        // ── AI bubble:  AiContentRenderer — unified pipeline Phase 10.
        //               Handles: LaTeX math (flutter_math_fork), Mermaid
        //               diagrams, and full Markdown. Never use bare
        //               MarkdownBody or Text() for AI responses.
        child: isUser
            ? SelectableText(
                message.text,
                style: const TextStyle(
                  color: Colors.white, fontSize: 14, height: 1.45,
                ),
              )
            : AiContentRenderer(
                content: message.text,
                isDark: true,   // PDF viewer always uses dark background
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
