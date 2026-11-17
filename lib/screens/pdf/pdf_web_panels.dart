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
import 'package:http/http.dart' as http;
// pdfx draws the PDF pages inside the page itself (pdf.js on web) - sharp,
// works on phones, and needs no Google viewer / iframe. This is the only
// file besides lib/services/pdf/pdfx_renderer.dart that imports pdfx.
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../models/pdf_chat.dart';
import '../../providers/ai_provider.dart';
import '../../widgets/ai_content_renderer.dart';  // Phase 10: unified renderer

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
// WebPdfPanel — in-page PDF viewer used by _buildWebLayout()
// ─────────────────────────────────────────────────────────────────────────────

/// Downloads the PDF and draws its pages inside the page (no iframe, no
/// Google viewer). Used in pdf_viewer_screen.dart -> _buildWebLayout().
class WebPdfPanel extends StatefulWidget {
  final String url;
  final String title;
  const WebPdfPanel({super.key, required this.url, required this.title});

  @override
  State<WebPdfPanel> createState() => _WebPdfPanelState();
}

class _WebPdfPanelState extends State<WebPdfPanel> {
  PdfControllerPinch? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _failed = false);
    try {
      final res = await http.get(Uri.parse(widget.url.trim()));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      if (!mounted) return;
      setState(() {
        _controller = PdfControllerPinch(
          document: PdfDocument.openData(res.bodyBytes),
        );
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Container(
        color: _kBackground,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Could not load this PDF.',
              style: TextStyle(color: _kTextPrimary, fontSize: 15),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                _controller?.dispose();
                _controller = null;
                _load();
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    final c = _controller;
    if (c == null) {
      return Container(
        color: _kBackground,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }
    return Container(
      color: _kBackground,
      child: PdfViewPinch(
        controller: c,
        onDocumentError: (_) {
          if (mounted) setState(() => _failed = true);
        },
      ),
    );
  }
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
  bool _userScrolledUp = false;
  bool _hasNewMessage  = false;
  static const _kScrollThreshold = 80.0;
  final _focusNode  = FocusNode();

  final List<_WebMessage> _messages = [];
  bool _loading = false;

  // Saved-chat resume (same behaviour as the mobile PDF AI sheet): the chat
  // of this PDF is loaded from the server when the panel opens. [_restoring]
  // blocks sending until that finished, so a question can never be added
  // before the saved ones.
  bool _restoring = false;
  bool _resumed   = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSavedChat());
    // BUG FIX: this listener was previously never attached (no initState
    // override existed), so _userScrolledUp never updated and the panel
    // always behaved as if the user were pinned to the bottom — i.e. it
    // would auto-scroll out from under anyone trying to read an earlier
    // reply. Attaching it here is what makes the "stay put while reading,
    // only jump when near the bottom" behaviour actually work.
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Loads the saved chat of this PDF. Any failure (offline, feature not
  /// available, not signed in) just leaves an empty chat - never blocks asking.
  Future<void> _restoreSavedChat() async {
    final id = widget.materialId;
    if (id == null) return;
    if (mounted) setState(() => _restoring = true);
    try {
      final data  = await ApiClient.getPdfChat(materialId: id);
      final items = (data['items'] as List?) ?? const [];
      final saved = pdfChatFromTurns(items);
      if (!mounted) return;
      if (saved.isNotEmpty && _messages.isEmpty) {
        setState(() {
          _messages.addAll([
            for (final m in saved)
              _WebMessage(text: m.text, isUser: m.isUser, sent: m.sent),
          ]);
          _resumed = true;
        });
        _scrollToBottom(force: true);
      }
    } catch (_) {
      // keep an empty chat
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _confirmStartOver() async {
    final id = widget.materialId;
    if (id == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start this chat over?'),
        content: const Text(
            'Your saved chat about this material will be deleted. '
            'Your AI usage is not affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep chat'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start over'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await ApiClient.deletePdfChat(materialId: id);
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _resumed = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start over. Please try again.')),
      );
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading || _restoring) return;
    _controller.clear();
    _focusNode.unfocus();
    await _askAi(text);
  }

  Future<void> _fireQuickAction(String action) async {
    final prompt = kPdfQuickPrompts[action] ?? action;
    final label  = kPdfQuickLabels[action]  ?? action;

    await _askAi(prompt, displayText: label);
  }

  Future<void> _askAi(String question, {String? displayText}) async {
    if (_loading || _restoring) return;

    // History = everything said so far in THIS PDF's chat (before this
    // question), so follow-ups like "explain that again" make sense.
    final history = pdfHistoryFor([
      for (final m in _messages)
        PdfChatEntry(
            text: m.text, sent: m.sent, isUser: m.isUser, isError: m.isError),
    ]);

    setState(() {
      _messages.add(_WebMessage(
        text: displayText ?? question,
        isUser: true,
        sent: question,
      ));
      _loading = true;
    });
    // The user just asked something — always jump to the bottom for
    // their own outgoing message, same as the other chat screens.
    setState(() {
      _userScrolledUp = false;
      _hasNewMessage  = false;
    });
    _scrollToBottom(force: true);

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
        // PDF questions never inherit history from saved AI Tutor chats;
        // they carry this PDF's own chat history instead.
        contextType:      'pdf',
        conversationHistory: history,
      );
      if (mounted) {
        setState(() {
          _messages.add(_WebMessage(
            text:   data['response'] as String,
            isUser: false,
          ));
          _loading = false;
          // The user may have scrolled up to re-read something while
          // waiting for this reply — don't yank them to the bottom,
          // just flag that a new message is waiting.
          if (_userScrolledUp) _hasNewMessage = true;
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
          if (_userScrolledUp) _hasNewMessage = true;
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
          if (_resumed) _buildResumedBanner(),
          _buildQuickActions(),
          const Divider(height: 1, color: Color(0xFF3A3A3A)),
          Expanded(
            child: Stack(
              children: [
                _buildMessageList(),
                if (_userScrolledUp)
                  Positioned(
                    right: 12,
                    bottom: 10,
                    child: _hasNewMessage
                        ? _WebNewMessagePill(
                            onTap: () {
                              setState(() {
                                _userScrolledUp = false;
                                _hasNewMessage  = false;
                              });
                              _scrollToBottom(force: true);
                            },
                          )
                        : _WebScrollToBottomButton(
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
    );
  }

  Widget _buildResumedBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
    color: _kAccent.withOpacity(0.08),
    child: Row(
      children: [
        const Icon(Icons.history_rounded, size: 16, color: _kAccent),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Continuing your saved chat',
            style: TextStyle(color: _kTextSecondary, fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: _loading ? null : _confirmStartOver,
          child: const Text('Start over', style: TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );

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
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _messages.length,
      itemBuilder: (_, i) => RepaintBoundary(
        child: _WebMessageBubble(message: _messages[i]),
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
// Scroll-to-bottom affordances (mirrors AiTutorScreen / AiLecturerScreen)
// ─────────────────────────────────────────────────────────────────────────────

class _WebScrollToBottomButton extends StatelessWidget {
  final VoidCallback onTap;
  const _WebScrollToBottomButton({required this.onTap});

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

class _WebNewMessagePill extends StatelessWidget {
  final VoidCallback onTap;
  const _WebNewMessagePill({required this.onTap});

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

// ─────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ─────────────────────────────────────────────────────────────────────────────

class _WebMessage {
  final String text;
  final String sent; // exact text sent to the AI (quick actions show a label)
  final bool   isUser;
  final bool   isError;
  const _WebMessage({
    required this.text,
    required this.isUser,
    String? sent,
    this.isError = false,
  }) : sent = sent ?? text;
}

class _WebMessageBubble extends StatelessWidget {
  final _WebMessage message;
  const _WebMessageBubble({required this.message});

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
                  : AiContentRenderer(
                      content: message.text,
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
