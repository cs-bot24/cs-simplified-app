import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/ai_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/ai_model.dart';
import '../../widgets/ai_message_content.dart';
import '../../widgets/ai_content_renderer.dart';
import '../../widgets/ai_streaming_renderer.dart';

class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key});
  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen>
    with SingleTickerProviderStateMixin {
  final _controller  = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _inputFocus  = FocusNode();
  bool  _showSettings = false;

  // ── Scroll architecture ───────────────────────────────────────────────────
  // One ListView.builder is the only scrollable in this screen (see
  // _MessageList below). Auto-scroll only ever runs in two situations:
  //   1. A new message is appended AND the user is already near the
  //      bottom (or it's their own outgoing message — see _send()).
  //   2. The user explicitly taps the "↓ New Message" affordance.
  // Anything else (the AI response rendering, the typing indicator
  // ticking, theme rebuilds, etc.) must NEVER move the scroll position.
  bool _userScrolledUp = false;

  static const _kScrollThreshold = 80.0; // px from bottom = "near bottom"

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ai = context.read<AiProvider>();
      ai.loadPlan();
      ai.loadUsage();
      // No-op unless Exam Prep pre-seeded this screen via prepareExamLesson().
      ai.beginExamLessonIfNeeded();
    });
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos        = _scrollCtrl.position;
    final nearBottom = pos.pixels >= pos.maxScrollExtent - _kScrollThreshold;
    final wantUp     = !nearBottom;
    if (wantUp != _userScrolledUp) {
      setState(() {
        _userScrolledUp = wantUp;
        if (!wantUp) _hasNewMessage = false; // back at bottom — clear badge
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _controller.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  /// Scrolls to bottom once. Called only when a NEW message is appended
  /// to the list (see _MessageList.didUpdateWidget) — never on every
  /// rebuild, and never while the message content itself is re-rendering.
  ///
  /// If the user has deliberately scrolled up to read older messages,
  /// this is a no-op unless [force] is true (used when the user sends
  /// their own message, or taps the "scroll to bottom" affordance).
  void _scrollToBottomIfNeeded({bool force = false}) {
    if (!_scrollCtrl.hasClients) return;
    if (_userScrolledUp && !force) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final ai   = context.read<AiProvider>();
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _inputFocus.unfocus();
    // The user just sent a message — always snap to bottom for it,
    // exactly like ChatGPT does when you hit send.
    setState(() {
      _userScrolledUp = false;
      _hasNewMessage  = false;
    });
    _scrollToBottomIfNeeded(force: true);
    await ai.ask(text);
    // Do NOT force-scroll again here: if the user started reading older
    // messages while the AI was responding, the new reply should only
    // auto-scroll into view if they're still near the bottom — that
    // gating now lives entirely in _MessageList.didUpdateWidget.
  }

  // Image upload is temporarily disabled — feature under development.
  void _onImageTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Image upload is currently under development. '
              'Please type your question as text.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ]),
        backgroundColor: const Color(0xFF1A3C6E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showPracticeDialog(BuildContext context) {
    final ai = context.read<AiProvider>();

    final String topic;
    if (ai.hasSessionContext) {
      topic = ai.sessionTopics.join(', ');
    } else {
      final lastAiMsg = ai.messages.lastWhere(
        (m) => !m.isUser,
        orElse: () => AiMessage(text: '', isUser: false, timestamp: DateTime.now()),
      );
      topic = lastAiMsg.subject ?? 'the topic we just discussed';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PracticeDialog(
        topic: topic,
        isSessionBased: ai.hasSessionContext,
      ),
    );
  }

  void _showStudyNotesDialog(BuildContext context) {
    final ai = context.read<AiProvider>();

    final String topic;
    if (ai.hasSessionContext) {
      topic = ai.sessionTopics.join(', ');
    } else {
      final lastAiMsg = ai.messages.lastWhere(
        (m) => !m.isUser,
        orElse: () => AiMessage(text: '', isUser: false, timestamp: DateTime.now()),
      );
      topic = lastAiMsg.subject ?? 'the topic we just discussed';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StudyNotesDialog(
        topic: topic,
        isSessionBased: ai.hasSessionContext,
      ),
    );
  }

  // True only while the user is scrolled up AND a message has arrived
  // since they scrolled away from the bottom. Drives the "↓ New Message"
  // pill. Plain "scrolled up with nothing new" shows no pill at all,
  // matching ChatGPT (no nag, just lets you keep reading).
  bool _hasNewMessage = false;

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;

    if (!auth.isLoggedIn) return _NotLoggedInView(scheme: scheme);

    return Scaffold(
      appBar: _buildAppBar(scheme),
      body: Column(
        children: [
          _ModeBar(scheme: scheme),
          if (_showSettings) _SettingsPanel(scheme: scheme),
          Expanded(child: Stack(
            children: [
              _MessageList(
                scrollCtrl: _scrollCtrl,
                scheme: scheme,
                isUserScrolledUp: _userScrolledUp,
                onNewMessageWhileScrolledUp: () {
                  if (_hasNewMessage) return;
                  // Defer — this fires from the child's didUpdateWidget,
                  // which runs as part of this widget's own build/update
                  // pass. Calling setState() synchronously here would be
                  // a setState-during-build hazard; scheduling it for the
                  // next frame is safe and still feels instant to the user.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_hasNewMessage) {
                      setState(() => _hasNewMessage = true);
                    }
                  });
                },
                onNewMessageAutoScrolled: _scrollToBottomIfNeeded,
              ),
              if (_userScrolledUp)
                Positioned(
                  right: 16,
                  bottom: 12,
                  child: _hasNewMessage
                      ? _NewMessagePill(
                          color: scheme.primary,
                          onTap: () {
                            setState(() {
                              _userScrolledUp = false;
                              _hasNewMessage  = false;
                            });
                            _scrollToBottomIfNeeded(force: true);
                          },
                        )
                      : FloatingActionButton.small(
                          heroTag: 'tutor_scroll_fab',
                          backgroundColor: scheme.primary,
                          elevation: 4,
                          onPressed: () {
                            setState(() => _userScrolledUp = false);
                            _scrollToBottomIfNeeded(force: true);
                          },
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                ),
            ],
          )),
          Consumer<AiProvider>(
            builder: (_, ai, __) => ai.error != null
                ? _ErrorBanner(error: ai.error!, scheme: scheme,
                    onDismiss: () => context.read<AiProvider>().clearError())
                : const SizedBox.shrink(),
          ),
          Consumer<AiProvider>(
            builder: (_, ai, __) => ai.examLessonAwaitingAction
                ? _ExamLessonActionBar(scheme: scheme)
                : const SizedBox.shrink(),
          ),
          _InputBar(
            controller: _controller,
            focusNode:  _inputFocus,
            onSend:     _send,
            onImageTap: _onImageTap,
            scheme:     scheme,
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(ColorScheme scheme) {
    return AppBar(
      title: Consumer<AiProvider>(
        builder: (_, ai, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ai.isExamLesson ? (ai.examTopic ?? 'Exam Lesson') : 'AI Tutor',
              style: const TextStyle(fontSize: 17),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (ai.isExamLesson)
              Text(ai.examCourseTitle ?? 'Exam Prep lesson',
                  style: TextStyle(fontSize: 11, color: scheme.primary.withOpacity(0.7)))
            else if (ai.questionsToday > 0)
              Text('${ai.questionsToday} questions today',
                  style: TextStyle(fontSize: 11, color: scheme.primary.withOpacity(0.7))),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(_showSettings ? Icons.tune : Icons.tune_outlined),
          tooltip: 'Settings',
          onPressed: () => setState(() => _showSettings = !_showSettings),
        ),
        Consumer<AiProvider>(
          builder: (_, ai, __) {
            if (ai.messages.isEmpty) return const SizedBox.shrink();
            return PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (val) {
                switch (val) {
                  case 'practice': _showPracticeDialog(context); break;
                  case 'notes':    _showStudyNotesDialog(context); break;
                  case 'clear':    _confirmClear(context); break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'practice',
                    child: ListTile(leading: Icon(Icons.quiz_rounded), title: Text('Practice Questions'), dense: true)),
                const PopupMenuItem(value: 'notes',
                    child: ListTile(leading: Icon(Icons.notes_rounded), title: Text('Study Notes'), dense: true)),
                const PopupMenuItem(value: 'clear',
                    child: ListTile(leading: Icon(Icons.delete_sweep_rounded), title: Text('Clear Chat'), dense: true)),
              ],
            );
          },
        ),
      ],
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text('All messages in this session will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () { context.read<AiProvider>().clearConversation(); Navigator.pop(context); },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}


// ── Mode Bar ──────────────────────────────────────────────────────────────────

class _ModeBar extends StatelessWidget {
  final ColorScheme scheme;
  const _ModeBar({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiProvider>();

    if (ai.isExamLesson) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.orange.withOpacity(0.08),
        child: Row(
          children: [
            const Icon(Icons.menu_book_rounded, size: 13, color: Colors.orange),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                ai.examIsReview
                    ? 'Previously completed • reviewing again'
                    : 'Exam Lesson • teaching from scratch',
                style: const TextStyle(
                    fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
              ),
            ),
            if (ai.examLessonMarkedComplete)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('✓ Completed',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green)),
              ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: scheme.primary.withOpacity(0.05),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 13, color: scheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Academic questions only • ${ai.level.name[0].toUpperCase()}${ai.level.name.substring(1)} level',
              style: TextStyle(fontSize: 11, color: scheme.primary),
            ),
          ),
          GestureDetector(
            onTap: () => context.read<AiProvider>().toggleExamPrep(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ai.isExamPrep
                    ? scheme.primary
                    : scheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_rounded,
                      size: 12,
                      color: ai.isExamPrep ? Colors.white : scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Exam Prep',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ai.isExamPrep ? Colors.white : scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ── Exam Lesson completion bar ────────────────────────────────────────────────
//
// Shown at the end of every Exam Lesson: "Mark this topic as completed?"
// with explicit ✓ Mark Complete / Review Again actions. Marking complete
// sends an explicit callback to Exam Prep (never inferred from chat text)
// and pops back so the Daily Topics card can refresh live.

class _ExamLessonActionBar extends StatefulWidget {
  final ColorScheme scheme;
  const _ExamLessonActionBar({required this.scheme});

  @override
  State<_ExamLessonActionBar> createState() => _ExamLessonActionBarState();
}

class _ExamLessonActionBarState extends State<_ExamLessonActionBar> {
  bool _justCompleted = false;

  Future<void> _onMarkComplete() async {
    final ai = context.read<AiProvider>();
    final ok = await ai.markExamTopicComplete();
    if (!mounted) return;
    if (ok) {
      setState(() => _justCompleted = true);
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ai.error ?? 'Could not save progress. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai      = context.watch<AiProvider>();
    final loading = ai.completingExamLesson;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: widget.scheme.primary.withOpacity(0.06),
        border: Border(top: BorderSide(color: widget.scheme.primary.withOpacity(0.15))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _justCompleted
                ? '✓ Nice work — marked as completed!'
                : 'Mark this topic as completed?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _justCompleted ? Colors.green : widget.scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: loading || _justCompleted
                      ? null
                      : () => context.read<AiProvider>().dismissExamLessonPrompt(),
                  child: const Text('Review Again'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: loading || _justCompleted ? null : _onMarkComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  icon: loading
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Mark Complete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// ── Settings Panel ────────────────────────────────────────────────────────────

class _SettingsPanel extends StatelessWidget {
  final ColorScheme scheme;
  const _SettingsPanel({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final ai     = context.watch<AiProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF8F9FF),
        border: Border(bottom: BorderSide(color: scheme.primary.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Explanation Level',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary)),
          const SizedBox(height: 8),
          Row(
            children: ExplanationLevel.values.map((lvl) {
              final selected = ai.level == lvl;
              final labels = {
                ExplanationLevel.beginner:     'Beginner',
                ExplanationLevel.intermediate: 'Intermediate',
                ExplanationLevel.advanced:     'Advanced',
              };
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => context.read<AiProvider>().setLevel(lvl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? scheme.primary : scheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        labels[lvl]!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : scheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}


// ── Message List ──────────────────────────────────────────────────────────────
//
// The single scrollable parent for the entire chat. Do not nest another
// ListView/SingleChildScrollView/CustomScrollView inside any list item —
// every message bubble below renders its full content as one static
// widget tree (see AiStreamingRenderer / AiBlockRenderer), so this is the
// only scroll gesture the user ever interacts with.

class _MessageList extends StatefulWidget {
  final ScrollController scrollCtrl;
  final ColorScheme scheme;
  final bool isUserScrolledUp;
  final VoidCallback onNewMessageWhileScrolledUp;
  final VoidCallback onNewMessageAutoScrolled;
  const _MessageList({
    required this.scrollCtrl,
    required this.scheme,
    required this.isUserScrolledUp,
    required this.onNewMessageWhileScrolledUp,
    required this.onNewMessageAutoScrolled,
  });

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  int _lastMessageCount = 0;

  @override
  void didUpdateWidget(_MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger exactly once per NEW message — driven by message count,
    // never by content re-rendering inside an existing message. This is
    // deliberately kept out of build(): scheduling a scroll mid-build can
    // race with the user's own drag gesture and cause the jump bugs this
    // architecture replaces.
    final ai = context.read<AiProvider>();
    if (ai.messages.length != _lastMessageCount) {
      _lastMessageCount = ai.messages.length;
      if (widget.isUserScrolledUp) {
        // Never yank the viewport while the user is deliberately reading
        // older messages — just flag that something new arrived.
        widget.onNewMessageWhileScrolledUp();
      } else {
        widget.onNewMessageAutoScrolled();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiProvider>();
    if (ai.messages.isEmpty) return _EmptyState(scheme: widget.scheme);

    final totalItems = ai.messages.length + (ai.loading ? 1 : 0);

    return ListView.builder(
      controller: widget.scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      cacheExtent: 500,
      // Standard platform physics (bouncing on iOS, clamping on
      // Android/desktop) is exactly what makes this feel identical to
      // ChatGPT — Flutter's default ScrollableState already cancels any
      // in-flight animateTo()/ballistic simulation the instant the user
      // touches the list, so no custom physics subclass is needed here.
      // AlwaysScrollable just guarantees drag works even when content is
      // shorter than the viewport (e.g. right after the first message).
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: totalItems,
      itemBuilder: (ctx, i) {
        if (ai.loading && i == ai.messages.length) {
          return const RepaintBoundary(child: _TypingIndicator());
        }
        return RepaintBoundary(
          child: _MessageBubble(
            key: ValueKey(ai.messages[i].timestamp.millisecondsSinceEpoch),
            message: ai.messages[i],
            scheme: widget.scheme,
          ),
        );
      },
    );
  }
}


/// The "↓ New Message" pill shown when a message has arrived while the
/// user was reading older content. Tapping it animates to the bottom —
/// it never auto-scrolls on its own.
class _NewMessagePill extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  const _NewMessagePill({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 15),
              SizedBox(width: 6),
              Text(
                'New Message',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
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


// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final AiMessage message;
  final ColorScheme scheme;
  const _MessageBubble({super.key, required this.message, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? scheme.primary
              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F4FF)),
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 12, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text('CS Simplified AI',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.primary)),
                  if (message.subject != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: scheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(message.subject!,
                          style: TextStyle(fontSize: 9, color: scheme.primary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  if (message.mode == AiMode.examPrep) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('EXAM', style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  if (message.mode == AiMode.examLesson) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('LESSON', style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
            ],
            isUser
                ? SelectableText(
                    message.text,
                    style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.5),
                  )
                : AiStreamingRenderer(
                    content: message.text,
                    isDark:  isDark,
                  ),
          ],
        ),
      ),
    );
  }
}


// ── Typing Indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override State<_TypingIndicator> createState() => _TypingIndicatorState();
}
class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F4FF),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16),
            bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4),
          ),
        ),
        child: FadeTransition(
          opacity: _anim,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome_rounded, size: 13, color: scheme.primary),
            const SizedBox(width: 6),
            Text('AI is thinking...', style: TextStyle(fontSize: 13, color: scheme.primary, fontStyle: FontStyle.italic)),
          ]),
        ),
      ),
    );
  }
}


// ── Input Bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onImageTap;
  final ColorScheme scheme;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onImageTap,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AiProvider>().loading;
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      padding: EdgeInsets.only(left: 8, right: 12, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
      child: Row(children: [
        // Image button — feature under development
        IconButton(
          icon: Icon(
            Icons.add_photo_alternate_outlined,
            color: Colors.grey.shade400,
          ),
          onPressed: loading ? null : onImageTap,
          tooltip: 'Image upload — coming soon',
        ),
        Expanded(
          // Windows desktop (Phase 2, Task 7/13): Enter sends the message,
          // Shift+Enter inserts a newline. Wrapped in a Focus so the
          // physical-keyboard case can be intercepted before the TextField's
          // own newline handling runs; gated to desktop only (`kIsWeb` false
          // and defaultTargetPlatform == windows) so Android's on-screen
          // keyboard 'return' key and web's existing behavior are completely
          // unchanged — this could not be tested on a real Windows machine
          // in this environment, see the Phase 2 report.
          child: Focus(
            onKeyEvent: (node, event) {
              final isDesktop =
                  !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
              if (!isDesktop) return KeyEventResult.ignored;
              final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter;
              if (event is KeyDownEvent &&
                  isEnter &&
                  !HardwareKeyboard.instance.isShiftPressed) {
                if (!loading) onSend();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !loading,
              maxLength: 2000,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ask a question...',
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true,
                fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F4FF),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        loading
            ? Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: scheme.primary.withOpacity(0.12), shape: BoxShape.circle),
                child: const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : Material(
                color: scheme.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSend,
                  child: const Padding(padding: EdgeInsets.all(10),
                      child: Icon(Icons.send_rounded, color: Colors.white, size: 22)),
                ),
              ),
      ]),
    );
  }
}


// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final ColorScheme scheme;
  const _EmptyState({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 16),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: scheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(24)),
          child: Icon(Icons.auto_awesome_rounded, size: 40, color: scheme.primary),
        ),
        const SizedBox(height: 20),
        Text('CS Simplified AI Tutor',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: scheme.primary)),
        const SizedBox(height: 8),
        Text('Ask academic questions, solve past questions, generate practice sets, and create study notes.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
        const SizedBox(height: 28),
        _SuggestionChip(label: 'Explain the OSI Model', icon: Icons.layers_rounded, scheme: scheme),
        const SizedBox(height: 8),
        _SuggestionChip(label: 'What is Big O notation?', icon: Icons.functions_rounded, scheme: scheme),
        const SizedBox(height: 8),
        _SuggestionChip(label: 'Which is not an OS: Linux, Windows, Oracle, Android?', icon: Icons.quiz_rounded, scheme: scheme),
        const SizedBox(height: 8),
        _SuggestionChip(label: 'Summarize this topic: Binary Trees', icon: Icons.notes_rounded, scheme: scheme),
        const SizedBox(height: 8),
        _SuggestionChip(label: 'Explain the difference between TCP and UDP', icon: Icons.compare_arrows_rounded, scheme: scheme),
      ]),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final ColorScheme scheme;
  const _SuggestionChip({required this.label, required this.icon, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.read<AiProvider>().ask(label),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.primary.withOpacity(0.15)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: scheme.primary))),
          Icon(Icons.north_west_rounded, size: 14, color: scheme.primary.withOpacity(0.5)),
        ]),
      ),
    );
  }
}


// ── Error Banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String error;
  final ColorScheme scheme;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.error, required this.scheme, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(error, style: const TextStyle(fontSize: 13, color: Colors.red))),
        GestureDetector(onTap: onDismiss, child: const Icon(Icons.close_rounded, color: Colors.red, size: 16)),
      ]),
    );
  }
}


// ── Practice Questions Dialog ─────────────────────────────────────────────────

class _PracticeDialog extends StatefulWidget {
  final String topic;
  final bool   isSessionBased;
  const _PracticeDialog({required this.topic, this.isSessionBased = false});
  @override State<_PracticeDialog> createState() => _PracticeDialogState();
}
class _PracticeDialogState extends State<_PracticeDialog> {
  String? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _result = null; });
    final result = await context.read<AiProvider>().generatePracticeQuestions(widget.topic);
    if (mounted) setState(() { _result = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Practice Questions'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isSessionBased)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 12, color: scheme.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'From this session: ${widget.topic}',
                        style: TextStyle(fontSize: 11, color: scheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            Flexible(
              child: _loading
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ))
                  : SingleChildScrollView(
                      child: AiContentRenderer(
                        content: _result ?? 'Could not generate questions. Please try again.',
                        isDark: Theme.of(context).brightness == Brightness.dark,
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        if (!_loading) TextButton(onPressed: _generate, child: const Text('Regenerate')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}


// ── Study Notes Dialog ────────────────────────────────────────────────────────

class _StudyNotesDialog extends StatefulWidget {
  final String topic;
  final bool   isSessionBased;
  const _StudyNotesDialog({required this.topic, this.isSessionBased = false});
  @override State<_StudyNotesDialog> createState() => _StudyNotesDialogState();
}
class _StudyNotesDialogState extends State<_StudyNotesDialog> {
  String? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _result = null; });
    final result = await context.read<AiProvider>().generateStudyNotes(widget.topic);
    if (mounted) setState(() { _result = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Study Notes'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isSessionBased)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notes_rounded, size: 12, color: scheme.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Summary of this session: ${widget.topic}',
                        style: TextStyle(fontSize: 11, color: scheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            Flexible(
              child: _loading
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ))
                  : SingleChildScrollView(
                      child: AiContentRenderer(
                        content: _result ?? 'Could not generate notes. Please try again.',
                        isDark: Theme.of(context).brightness == Brightness.dark,
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        if (!_loading) TextButton(onPressed: _generate, child: const Text('Regenerate')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}


// ── Not Logged In ─────────────────────────────────────────────────────────────

class _NotLoggedInView extends StatelessWidget {
  final ColorScheme scheme;
  const _NotLoggedInView({required this.scheme});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Tutor')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.account_circle_rounded, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            const Text('Sign in to use AI Tutor', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('AI Tutor is available to registered students.', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
          ]),
        ),
      ),
    );
  }
}
