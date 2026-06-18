// lib/screens/pdf/pdf_web_panels.dart
//
// WEB-ONLY implementation.
// Loaded via conditional import in pdf_viewer_screen.dart:
//   import 'pdf_web_panels_stub.dart'
//       if (dart.library.html) 'pdf_web_panels.dart';
//
// This file MUST NOT be imported directly — only through the conditional
// import above, because dart:ui_web and dart:html are not available on
// mobile/desktop.

// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../providers/ai_provider.dart';
import '../../widgets/ai_message_content.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Internal colour constants (mirrors pdf_viewer_screen.dart)
// ─────────────────────────────────────────────────────────────────────────────
const _kBackground   = Color(0xFF1A1A1A);
const _kSurface      = Color(0xFF2C2C2C);
const _kSurfaceLight = Color(0xFF383838);
const _kAccent       = Color(0xFF6C63FF);
const _kTextPrimary  = Colors.white;
const _kTextSecondary = Color(0xFFAAAAAA);
const _kUserBubble   = Color(0xFF6C63FF);
const _kAiBubble     = Color(0xFF2C2C2C);

// ─────────────────────────────────────────────────────────────────────────────
// View-factory registration
// ─────────────────────────────────────────────────────────────────────────────

/// Registers a view factory for [viewType] that renders [url] in an <iframe>.
/// Must be called once before building a [PdfWebView] with the same [viewType].
void registerPdfViewFactory(String viewType, String url) {
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width  = '100%'
      ..style.height = '100%'
      ..allowFullscreen = true;

    iframe.setAttribute('allow', 'fullscreen');
    return iframe;
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PdfWebView — raw HtmlElementView wrapper
// ─────────────────────────────────────────────────────────────────────────────

/// Displays a previously-registered iframe view factory.
class PdfWebView extends StatelessWidget {
  final String viewType;
  const PdfWebView({super.key, required this.viewType});

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: viewType);
}

// ─────────────────────────────────────────────────────────────────────────────
// WebPdfPanel — iframe panel used by _buildWebLayout()
// ─────────────────────────────────────────────────────────────────────────────

/// Registers the iframe factory in [initState] then renders [PdfWebView].
/// Used in pdf_viewer_screen.dart → _buildWebLayout() as the PDF surface.
class WebPdfPanel extends StatefulWidget {
  final String url;
  final String title;
  const WebPdfPanel({super.key, required this.url, required this.title});

  @override
  State<WebPdfPanel> createState() => _WebPdfPanelState();
}

class _WebPdfPanelState extends State<WebPdfPanel> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    // Use a stable key so hot-reload doesn't re-register the same factory.
    _viewType = 'pdf-viewer-${widget.url.hashCode}';
    registerPdfViewFactory(_viewType, widget.url);
  }

  @override
  Widget build(BuildContext context) => PdfWebView(viewType: _viewType);
}

// ─────────────────────────────────────────────────────────────────────────────
// WebAiPanel — right-side AI chat drawer used by _buildWebAiOverlay()
// ─────────────────────────────────────────────────────────────────────────────

/// Full AI chat panel rendered as a right-side drawer on web.
/// Mirrors the _AiBottomSheet experience from the mobile build but
/// displayed as a persistent side panel instead of a bottom sheet.
class WebAiPanel extends StatefulWidget {
  final int?    materialId;
  final String  materialTitle;
  final String? courseCode;
  final String? levelName;
  final String? categoryName;
  final VoidCallback onClose;

  const WebAiPanel({
    super.key,
    required this.materialId,
    required this.materialTitle,
    required this.courseCode,
    required this.levelName,
    required this.categoryName,
    required this.onClose,
  });

  @override
  State<WebAiPanel> createState() => _WebAiPanelState();
}

class _WebAiPanelState extends State<WebAiPanel> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();

  final List<_WebMessage> _messages = [];
  bool _loading = false;

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
    _focusNode.unfocus();
    await _askAi(text);
  }

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
      _messages.add(_WebMessage(text: displayText ?? question, isUser: true));
      _loading = true;
    });
    _scrollToBottom();

    try {
      final ai = context.read<AiProvider>();
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
          _messages.add(_WebMessage(
            text:   data['response'] as String,
            isUser: false,
          ));
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add(_WebMessage(
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBackground,
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

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        // Context indicator
        if (widget.courseCode != null)
          Container(
            margin: const EdgeInsets.only(right: 8),
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
        // Close button
        IconButton(
          icon: const Icon(Icons.close, color: _kTextSecondary, size: 20),
          onPressed: widget.onClose,
          tooltip: 'Close',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    ),
  );

  Widget _buildQuickActions() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        _QuickChip(
          icon: Icons.auto_awesome_rounded,
          label: 'Explain',
          onTap: _loading ? null : () => _fireQuickAction('explain'),
        ),
        const SizedBox(width: 8),
        _QuickChip(
          icon: Icons.notes_rounded,
          label: 'Notes',
          onTap: _loading ? null : () => _fireQuickAction('notes'),
        ),
        const SizedBox(width: 8),
        _QuickChip(
          icon: Icons.quiz_rounded,
          label: 'Quiz Me',
          onTap: _loading ? null : () => _fireQuickAction('quiz'),
        ),
      ],
    ),
  );

  Widget _buildMessageList() {
    if (_messages.isEmpty) return _buildEmptyState();
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _messages.length,
      itemBuilder: (_, i) => _WebMessageBubble(message: _messages[i]),
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
            'Or use Explain, Notes, or Quiz Me above',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF666666), fontSize: 11),
          ),
        ],
      ),
    ),
  );

  Widget _buildTypingIndicator() => Padding(
    padding: const EdgeInsets.only(left: 12, bottom: 8),
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
    padding: const EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 12),
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
              controller:      _controller,
              focusNode:       _focusNode,
              enabled:         !_loading,
              maxLines:        4,
              minLines:        1,
              textInputAction: TextInputAction.send,
              onSubmitted:     (_) => _send(),
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

// ─────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ─────────────────────────────────────────────────────────────────────────────

class _WebMessage {
  final String text;
  final bool   isUser;
  final bool   isError;
  const _WebMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}

class _WebMessageBubble extends StatelessWidget {
  final _WebMessage message;
  const _WebMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kAccent, Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Text('AI', style: TextStyle(
                  color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold,
                )),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? _kUserBubble
                    : (message.isError
                        ? Colors.red.withOpacity(0.15)
                        : _kAiBubble),
                borderRadius: BorderRadius.only(
                  topLeft:     Radius.circular(isUser ? 16 : 4),
                  topRight:    Radius.circular(isUser ? 4  : 16),
                  bottomLeft:  const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
              ),
              child: isUser
                  ? Text(
                      message.text,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.4,
                      ),
                    )
                  : AiMessageContent(
                      data: message.text,
                      isDark: true,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback? onTap;
  const _QuickChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kSurfaceLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kAccent.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: _kAccent),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(
                color: _kTextPrimary, fontSize: 12, fontWeight: FontWeight.w500,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(
      width: 6, height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: const BoxDecoration(
        color: _kTextSecondary,
        shape: BoxShape.circle,
      ),
    ),
  );
}
