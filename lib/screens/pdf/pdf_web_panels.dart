// lib/screens/pdf/pdf_web_panels.dart
//
// Web-exclusive split-screen components used by pdf_viewer_screen.dart.
//
// WebPdfPanel  — Left panel: renders the PDF in an iframe via HtmlElementView.
// WebAiPanel   — Right panel: persistent AI chat (mirrors the mobile bottom sheet).
//
// Classes are PUBLIC so pdf_viewer_screen.dart can import and use them.
// dart:ui_web (platformViewRegistry) is accessed only on web via kIsWeb guard.

// ignore_for_file: avoid_web_libraries_in_flutter
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
// dart:html is only available on web; conditional import keeps mobile clean.
import 'web_iframe_stub.dart'
    if (dart.library.html) 'web_iframe_impl.dart';

import '../../core/api_client.dart';
import '../../providers/ai_provider.dart';

// ── Colours (matches pdf_viewer_screen constants) ─────────────────────────────
const _kBg        = Color(0xFF1A1A1A);
const _kSurface   = Color(0xFF2C2C2C);
const _kSurface2  = Color(0xFF383838);
const _kAccent    = Color(0xFF6C63FF);
const _kAccentLt  = Color(0xFF8B85FF);
const _kTextPri   = Colors.white;
const _kTextSec   = Color(0xFFAAAAAA);
const _kUserBubble = Color(0xFF6C63FF);
const _kAiBubble   = Color(0xFF2C2C2C);


// ══════════════════════════════════════════════════════════════════════════════
// Left Panel: PDF Viewer (iframe)
// ══════════════════════════════════════════════════════════════════════════════

class WebPdfPanel extends StatefulWidget {
  final String url;
  final String title;
  const WebPdfPanel({super.key, required this.url, required this.title});

  @override
  State<WebPdfPanel> createState() => _WebPdfPanelState();
}

class _WebPdfPanelState extends State<WebPdfPanel> {
  bool   _registered = false;
  late final String _viewType;

  String get _viewerUrl {
    final encoded = Uri.encodeComponent(widget.url.trim());
    return 'https://drive.google.com/viewerng/viewer?embedded=true&url=$encoded';
  }

  @override
  void initState() {
    super.initState();
    _viewType = 'pdf-iframe-${widget.url.hashCode}';
    if (kIsWeb) _registerIframe();
  }

  void _registerIframe() {
    if (_registered) return;
    _registered = true;
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => createIframeElement(_viewerUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: _kSurface,
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded,
                    color: _kAccentLt, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                        color: _kTextPri,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded,
                      color: _kTextSec, size: 18),
                  tooltip: 'Open in new tab',
                  onPressed: () => launchUrl(
                    Uri.parse(widget.url),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ),
          // iframe / fallback
          Expanded(
            child: kIsWeb
                ? HtmlElementView(viewType: _viewType)
                : const Center(
                    child: Text(
                      'PDF viewer is only available on web.',
                      style: TextStyle(color: _kTextSec),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// Right Panel: Persistent AI Chat
// ══════════════════════════════════════════════════════════════════════════════

class WebAiPanel extends StatefulWidget {
  final int?    materialId;
  final String  materialTitle;
  final String? courseCode;
  final String? levelName;
  final String? categoryName;
  final VoidCallback? onClose;

  const WebAiPanel({
    super.key,
    required this.materialTitle,
    this.materialId,
    this.courseCode,
    this.levelName,
    this.categoryName,
    this.onClose,
  });

  @override
  State<WebAiPanel> createState() => _WebAiPanelState();
}

class _WebAiPanelState extends State<WebAiPanel> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();
  final List<_Msg>  _messages = [];
  bool              _loading  = false;

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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    _controller.clear();
    _focusNode.requestFocus();
    await _ask(text);
  }

  Future<void> _quickAction(String action) async {
    final prompt = switch (action) {
      'explain' =>
        'Please explain the key concepts, important definitions, '
        'and main ideas in this course material. Also include any exam tips.',
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
    await _ask(prompt, display: label);
  }

  Future<void> _ask(String question, {String? display}) async {
    if (_loading) return;
    setState(() {
      _messages.add(_Msg(text: display ?? question, isUser: true));
      _loading = true;
    });
    _scrollToBottom();

    try {
      final ai   = context.read<AiProvider>();
      final data = await ApiClient.askAi(
        question:         question,
        mode:             ai.isExamPrep ? 'exam_prep' : 'normal',
        level:            ai.level.name,
        pdfMaterialId:    widget.materialId,
        pdfMaterialTitle: widget.materialTitle,
        pdfCourseCode:    widget.courseCode,
        pdfLevelName:     widget.levelName,
        pdfCategoryName:  widget.categoryName,
      );
      if (mounted) {
        setState(() {
          _messages.add(_Msg(text: data['response'] as String, isUser: false));
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add(_Msg(
              text: 'Something went wrong. Please try again.',
              isUser: false,
              isError: true));
          _loading = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kSurface,
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1, color: Color(0xFF3A3A3A)),
          _buildQuickActions(),
          const Divider(height: 1, color: Color(0xFF3A3A3A)),
          Expanded(child: _buildMessageList()),
          if (_loading) _buildTypingIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    color: _kSurface,
    child: Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kAccent, Color(0xFF9C27B0)]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text('AI',
                style: TextStyle(color: Colors.white,
                    fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AI Tutor',
                  style: TextStyle(color: _kTextPri,
                      fontSize: 14, fontWeight: FontWeight.w700)),
              Text(
                widget.courseCode != null
                    ? '${widget.courseCode} · ${widget.materialTitle}'
                    : widget.materialTitle,
                style: const TextStyle(color: _kTextSec, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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
                        color: Colors.greenAccent, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('Context on',
                    style: TextStyle(color: Colors.greenAccent,
                        fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        if (widget.onClose != null)
          IconButton(
            icon: const Icon(Icons.close_rounded, color: _kTextSec, size: 20),
            tooltip: 'Close AI panel',
            onPressed: widget.onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
      ],
    ),
  );

  Widget _buildQuickActions() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    color: _kBg,
    child: Row(
      children: [
        _QuickBtn(icon: Icons.lightbulb_outline_rounded, label: 'Explain',
            onTap: () => _quickAction('explain')),
        const SizedBox(width: 8),
        _QuickBtn(icon: Icons.notes_rounded, label: 'Notes',
            onTap: () => _quickAction('notes')),
        const SizedBox(width: 8),
        _QuickBtn(icon: Icons.quiz_outlined, label: 'Quiz Me',
            onTap: () => _quickAction('quiz')),
      ],
    ),
  );

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: _kAccent.withOpacity(0.4), size: 36),
              const SizedBox(height: 10),
              Text(
                widget.courseCode != null
                    ? 'Ask anything about ${widget.courseCode}'
                    : 'Ask anything about this material',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kTextSec, fontSize: 13),
              ),
              const SizedBox(height: 6),
              const Text(
                'Or tap Explain, Notes, or Quiz Me above',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF555555), fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _MsgBubble(msg: _messages[i]),
    );
  }

  Widget _buildTypingIndicator() => Padding(
    padding: const EdgeInsets.only(left: 16, bottom: 8),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: _kAiBubble, borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) => _Dot(delay: i * 200)),
          ),
        ),
      ],
    ),
  );

  Widget _buildInputBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _kSurface,
      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
    ),
    child: Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
                color: _kSurface2, borderRadius: BorderRadius.circular(24)),
            child: TextField(
              controller:      _controller,
              focusNode:       _focusNode,
              enabled:         !_loading,
              maxLines:        4,
              minLines:        1,
              textInputAction: TextInputAction.send,
              onSubmitted:     (_) => _send(),
              style: const TextStyle(color: _kTextPri, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Ask about this material…',
                hintStyle: TextStyle(color: _kTextSec, fontSize: 14),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _loading ? null : _send,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40, height: 40,
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


// ── Quick action button ───────────────────────────────────────────────────────

class _QuickBtn extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  const _QuickBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kAccent.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: _kAccentLt, size: 14),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(
                    color: _kAccentLt, fontSize: 11,
                    fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ── Message model & bubble ────────────────────────────────────────────────────

class _Msg {
  final String text;
  final bool   isUser;
  final bool   isError;
  const _Msg({required this.text, required this.isUser, this.isError = false});
}

class _MsgBubble extends StatelessWidget {
  final _Msg msg;
  const _MsgBubble({super.key, required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isError
              ? Colors.red.withOpacity(0.15)
              : isUser
                  ? _kUserBubble
                  : _kAiBubble,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: msg.isError
              ? Border.all(color: Colors.red.withOpacity(0.3))
              : null,
        ),
        child: isUser
            ? SelectableText(msg.text,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.45))
            : MarkdownBody(
                data: msg.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                      color: Color(0xFFDDDDDD), fontSize: 14, height: 1.55),
                  h1: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold,
                      color: Colors.white),
                  h2: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold,
                      color: Colors.white),
                  h3: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: Colors.white),
                  strong: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                  em: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Color(0xFFCCCCCC)),
                  code: const TextStyle(
                      fontFamily: 'monospace', fontSize: 13,
                      backgroundColor: Color(0xFF1A1A1A),
                      color: Color(0xFF82B1FF)),
                  codeblockDecoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  codeblockPadding: const EdgeInsets.all(12),
                  blockquote: const TextStyle(
                      fontSize: 14, color: Color(0xFFAAAAAA),
                      fontStyle: FontStyle.italic),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                          color: _kAccent.withOpacity(0.5), width: 3),
                    ),
                  ),
                  blockquotePadding:
                      const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                  listBullet: const TextStyle(color: Color(0xFFDDDDDD)),
                ),
              ),
      ),
    );
  }
}


// ── Typing dot animation ──────────────────────────────────────────────────────

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween<double>(begin: 0, end: -5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
              color: _kAccentLt, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
