// lib/screens/lecturer/ai_lecturer_screen.dart
//
// AI Lecturer — Structured Teaching Mode
//
// The student selects a course, picks their level, and the AI teaches
// the entire course chapter by chapter, ending each lesson with a
// check question before allowing the student to advance.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../../models/lecturer_model.dart';
import '../../providers/lecturer_provider.dart';
import '../../theme/app_theme.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────
const _kAccent  = Color(0xFF1A3C6E);   // matches AppTheme.primary
const _kAccentL = Color(0xFF2E6DA4);   // matches AppTheme.primaryLight

// ══════════════════════════════════════════════════════════════════════════════
// Entry point
// ══════════════════════════════════════════════════════════════════════════════

class AiLecturerScreen extends StatelessWidget {
  const AiLecturerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LecturerProvider(),
      child: const _LecturerView(),
    );
  }
}

class _LecturerView extends StatelessWidget {
  const _LecturerView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LecturerProvider>();
    if (!provider.hasSession) return const _SetupScreen();
    return const _SessionScreen();
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// Setup Screen — pick course and level
// ══════════════════════════════════════════════════════════════════════════════

class _SetupScreen extends StatefulWidget {
  const _SetupScreen();
  @override State<_SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<_SetupScreen> {
  final _courseNameCtrl = TextEditingController();
  final _courseCodeCtrl = TextEditingController();
  String _level         = 'intermediate';
  bool   _loading       = false;

  // Predefined CS course suggestions for quick selection
  static const _suggestions = [
    ('Data Structures & Algorithms', 'CSC 201'),
    ('Operating Systems',            'CSC 301'),
    ('Computer Networks',            'CSC 311'),
    ('Database Systems',             'CSC 321'),
    ('Object-Oriented Programming',  'CSC 211'),
    ('Discrete Mathematics',         'MTH 201'),
    ('Software Engineering',         'CSC 401'),
    ('Computer Architecture',        'CSC 231'),
    ('Artificial Intelligence',      'CSC 421'),
    ('Web Development',              'CSC 351'),
  ];

  @override
  void dispose() {
    _courseNameCtrl.dispose();
    _courseCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final name = _courseNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a course name.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _loading = true);
    final provider = context.read<LecturerProvider>();
    provider.setSession(
      courseName: name,
      courseCode: _courseCodeCtrl.text.trim(),
      level:      _level,
    );
    await provider.loadCurriculum();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Lecturer'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Hero card ──────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kAccent, _kAccentL],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.school_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AI Lecturer',
                                style: TextStyle(color: Colors.white,
                                    fontSize: 20, fontWeight: FontWeight.w800)),
                            Text('Structured Course Teaching',
                                style: TextStyle(color: Colors.white70,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your personal AI lecturer teaches entire courses '
                    'chapter by chapter — with lessons, examples, and '
                    'check questions to ensure you truly understand before moving on.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            Text('What would you like to study?',
                style: TextStyle(color: scheme.onSurface,
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Type any course or pick a suggestion below.',
                style: TextStyle(color: scheme.onSurface.withOpacity(0.5),
                    fontSize: 13)),

            const SizedBox(height: 16),

            // ── Course name field ──────────────────────────────────────────
            TextField(
              controller: _courseNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Course Name *',
                hintText: 'e.g. Data Structures & Algorithms',
                prefixIcon: const Icon(Icons.book_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // ── Course code field ──────────────────────────────────────────
            TextField(
              controller: _courseCodeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Course Code (optional)',
                hintText: 'e.g. CSC 201',
                prefixIcon: const Icon(Icons.tag_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 20),

            // ── Level picker ───────────────────────────────────────────────
            Text('Your Level',
                style: TextStyle(color: scheme.onSurface,
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            _LevelPicker(
              selected: _level,
              onSelect: (l) => setState(() => _level = l),
            ),

            const SizedBox(height: 24),

            // ── Start button ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _start,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  disabledBackgroundColor: _kAccent.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text('Start Course',
                              style: TextStyle(color: Colors.white,
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Quick suggestions ──────────────────────────────────────────
            Text('Popular Courses',
                style: TextStyle(color: scheme.onSurface,
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions.map((s) {
                return GestureDetector(
                  onTap: () => setState(() {
                    _courseNameCtrl.text = s.$1;
                    _courseCodeCtrl.text = s.$2;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _kAccent.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(s.$2,
                              style: const TextStyle(
                                  color: _kAccentL, fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Text(s.$1,
                            style: TextStyle(
                                color: scheme.onSurface, fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// Session Screen — the teaching experience
// ══════════════════════════════════════════════════════════════════════════════

class _SessionScreen extends StatefulWidget {
  const _SessionScreen();
  @override State<_SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<_SessionScreen> {
  final _scrollCtrl  = ScrollController();
  final _answerCtrl  = TextEditingController();
  final _answerFocus = FocusNode();
  bool  _showChapters = false;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _answerCtrl.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _submitAnswer() async {
    final answer = _answerCtrl.text.trim();
    if (answer.isEmpty) return;
    _answerCtrl.clear();
    _answerFocus.unfocus();
    final provider = context.read<LecturerProvider>();
    await provider.submitCheckAnswer(answer);
    _scrollToBottom();
  }

  Future<void> _advance() async {
    final provider = context.read<LecturerProvider>();
    await provider.advanceToNextChapter();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LecturerProvider>();
    final scheme   = Theme.of(context).colorScheme;
    final curriculum = provider.curriculum!;

    // Auto-scroll when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _confirmReset(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(curriculum.courseName,
                style: const TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
            Text(
              '${(provider.overallProgress * 100).toStringAsFixed(0)}% complete'
              ' · ${curriculum.chapters.length} chapters',
              style: TextStyle(fontSize: 11,
                  color: scheme.primary.withOpacity(0.7)),
            ),
          ],
        ),
        actions: [
          // Chapter list toggle
          IconButton(
            icon: Icon(_showChapters
                ? Icons.list_rounded
                : Icons.list_outlined),
            tooltip: 'Chapter List',
            onPressed: () => setState(
                () => _showChapters = !_showChapters),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value:            provider.overallProgress,
            backgroundColor:  scheme.primary.withOpacity(0.12),
            valueColor:       AlwaysStoppedAnimation(scheme.primary),
            minHeight:        4,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Chapter list drawer ──────────────────────────────────────────
          if (_showChapters)
            _ChapterDrawer(
              chapters: provider.chapters,
              current:  provider.currentIndex,
              onTap: (i) {
                final ch = provider.chapters[i];
                if (ch.state != ChapterState.locked) {
                  setState(() => _showChapters = false);
                  provider.loadChapter(i).then((_) => _scrollToBottom());
                }
              },
            ),

          // ── Error banner ─────────────────────────────────────────────────
          if (provider.error != null)
            _ErrorBanner(
              error: provider.error!,
              onDismiss: provider.clearError,
            ),

          // ── Message list ─────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller:  _scrollCtrl,
              padding:     const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount:   provider.messages.length,
              itemBuilder: (_, i) => _MessageTile(
                  message: provider.messages[i],
                  scheme:  scheme),
            ),
          ),

          // ── Loading indicator ─────────────────────────────────────────────
          if (provider.state == LecturerState.loadingLesson ||
              provider.state == LecturerState.checking)
            _LoadingBar(
              label: provider.state == LecturerState.loadingLesson
                  ? 'AI Lecturer is preparing your lesson…'
                  : 'Evaluating your answer…',
              scheme: scheme,
            ),

          // ── Action area ───────────────────────────────────────────────────
          _ActionArea(
            provider:    provider,
            answerCtrl:  _answerCtrl,
            answerFocus: _answerFocus,
            scheme:      scheme,
            onSubmit:    _submitAnswer,
            onAdvance:   _advance,
            onStartFirst: () {
              provider.loadChapter(0).then((_) => _scrollToBottom());
            },
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Exit Course?'),
        content: const Text(
            'Your current session progress will be lost. '
            'Are you sure you want to go back?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Stay')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<LecturerProvider>().reset();
            },
            child: const Text('Exit',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// Action Area — adapts based on session state
// ══════════════════════════════════════════════════════════════════════════════

class _ActionArea extends StatelessWidget {
  final LecturerProvider  provider;
  final TextEditingController answerCtrl;
  final FocusNode         answerFocus;
  final ColorScheme       scheme;
  final VoidCallback      onSubmit;
  final VoidCallback      onAdvance;
  final VoidCallback      onStartFirst;

  const _ActionArea({
    required this.provider,
    required this.answerCtrl,
    required this.answerFocus,
    required this.scheme,
    required this.onSubmit,
    required this.onAdvance,
    required this.onStartFirst,
  });

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final isLoading = provider.state == LecturerState.loadingLesson ||
        provider.state == LecturerState.checking ||
        provider.state == LecturerState.loadingCurriculum;
    final current  = provider.currentChapter;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: _buildContent(context, isDark, isLoading, current),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark,
      bool isLoading, ChapterProgress? current) {

    // Course just loaded — show "Start Lesson" for chapter 1
    if (current != null && current.lessonText == null &&
        current.state == ChapterState.current && !isLoading) {
      return _StartChapterButton(
        chapter: current.chapter,
        scheme:  scheme,
        onTap:   onStartFirst,
      );
    }

    // Check question phase — student must answer before advancing
    if (current != null &&
        current.state == ChapterState.checking &&
        current.checkFeedback == null &&
        !isLoading) {
      return _AnswerInput(
        ctrl:       answerCtrl,
        focusNode:  answerFocus,
        scheme:     scheme,
        isDark:     isDark,
        onSubmit:   onSubmit,
        isLoading:  isLoading,
        checkQuestion: current.checkQuestion,
      );
    }

    // Feedback received — show Next Chapter button
    if (current != null && current.checkFeedback != null && !isLoading) {
      if (provider.isLastChapter && current.state != ChapterState.passed) {
        return _CourseCompleteButton(scheme: scheme, onTap: onAdvance);
      }
      return _NextChapterButton(
        nextIndex: provider.currentIndex + 2,
        scheme:    scheme,
        onTap:     onAdvance,
        isLast:    provider.isLastChapter,
      );
    }

    // Loading — show disabled placeholder
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Text('Please wait…',
            style: TextStyle(
                color: scheme.onSurface.withOpacity(0.3))),
      ),
    );
  }
}


// ── Start Chapter Button ──────────────────────────────────────────────────────

class _StartChapterButton extends StatelessWidget {
  final LecturerChapter chapter;
  final ColorScheme     scheme;
  final VoidCallback    onTap;
  const _StartChapterButton({
    required this.chapter,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kAccent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_fill_rounded,
                color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Start Chapter ${chapter.index}: ${chapter.title}',
                style: const TextStyle(color: Colors.white,
                    fontSize: 14, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Answer Input ──────────────────────────────────────────────────────────────

class _AnswerInput extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode             focusNode;
  final ColorScheme           scheme;
  final bool                  isDark;
  final VoidCallback          onSubmit;
  final bool                  isLoading;
  final String?               checkQuestion;

  const _AnswerInput({
    required this.ctrl,
    required this.focusNode,
    required this.scheme,
    required this.isDark,
    required this.onSubmit,
    required this.isLoading,
    this.checkQuestion,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Check question reminder
        if (checkQuestion != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kAccent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.help_outline_rounded,
                    color: scheme.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    checkQuestion!,
                    style: TextStyle(
                        color: scheme.onSurface, fontSize: 12,
                        fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
        Row(children: [
          Expanded(
            child: TextField(
              controller:      ctrl,
              focusNode:       focusNode,
              enabled:         !isLoading,
              maxLines:        3,
              minLines:        1,
              textInputAction: TextInputAction.send,
              onSubmitted:     (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: 'Type your answer here…',
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFF0F4FF),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color:      _kAccent,
            shape:      const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: isLoading ? null : onSubmit,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
      ],
    );
  }
}


// ── Next Chapter Button ───────────────────────────────────────────────────────

class _NextChapterButton extends StatelessWidget {
  final int          nextIndex;
  final ColorScheme  scheme;
  final VoidCallback onTap;
  final bool         isLast;
  const _NextChapterButton({
    required this.nextIndex,
    required this.scheme,
    required this.onTap,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isLast ? Colors.green[700] : _kAccent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isLast
                ? Icons.emoji_events_rounded
                : Icons.arrow_forward_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              isLast
                  ? 'Complete Course 🎓'
                  : 'Next Chapter ($nextIndex)',
              style: const TextStyle(color: Colors.white,
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseCompleteButton extends StatelessWidget {
  final ColorScheme  scheme;
  final VoidCallback onTap;
  const _CourseCompleteButton(
      {required this.scheme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_rounded,
                color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text('Finish Course 🎓',
                style: TextStyle(color: Colors.white,
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// Chapter Drawer — collapsible chapter list
// ══════════════════════════════════════════════════════════════════════════════

class _ChapterDrawer extends StatelessWidget {
  final List<ChapterProgress> chapters;
  final int                   current;
  final void Function(int)    onTap;
  const _ChapterDrawer({
    required this.chapters,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final scheme  = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F9FF),
        border: Border(
            bottom: BorderSide(
                color: scheme.primary.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Course Chapters',
                style: TextStyle(color: scheme.onSurface,
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap:  true,
              padding:     const EdgeInsets.only(bottom: 8),
              itemCount:   chapters.length,
              itemBuilder: (_, i) {
                final ch = chapters[i];
                final isCurrent = i == current;
                final locked = ch.state == ChapterState.locked;
                final passed = ch.state == ChapterState.passed;

                return InkWell(
                  onTap: locked ? null : () => onTap(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? scheme.primary.withOpacity(0.08)
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Chapter state icon
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: passed
                                ? Colors.green.withOpacity(0.15)
                                : isCurrent
                                    ? scheme.primary.withOpacity(0.15)
                                    : locked
                                        ? Colors.grey.withOpacity(0.1)
                                        : scheme.primary.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            passed
                                ? Icons.check_rounded
                                : isCurrent
                                    ? Icons.play_arrow_rounded
                                    : locked
                                        ? Icons.lock_rounded
                                        : Icons.circle_outlined,
                            size: 14,
                            color: passed
                                ? Colors.green
                                : isCurrent
                                    ? scheme.primary
                                    : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chapter ${ch.chapter.index}',
                                style: TextStyle(
                                  color: locked
                                      ? Colors.grey
                                      : scheme.onSurface.withOpacity(0.5),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                ch.chapter.title,
                                style: TextStyle(
                                  color: locked
                                      ? Colors.grey
                                      : scheme.onSurface,
                                  fontSize: 13,
                                  fontWeight: isCurrent
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(ch.chapter.durationEstimate,
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// Message Tile — renders lessons, answers, feedback, system messages
// ══════════════════════════════════════════════════════════════════════════════

class _MessageTile extends StatelessWidget {
  final LecturerMessage message;
  final ColorScheme     scheme;
  const _MessageTile({required this.message, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (message.type) {
      case LecturerMessageType.system:
        return _SystemMessage(text: message.text, scheme: scheme, isDark: isDark);
      case LecturerMessageType.studentAnswer:
        return _StudentBubble(text: message.text, scheme: scheme);
      case LecturerMessageType.lesson:
      case LecturerMessageType.feedback:
        return _LecturerBubble(
            text: message.text, scheme: scheme, isDark: isDark,
            isFeedback: message.type == LecturerMessageType.feedback);
    }
  }
}

class _SystemMessage extends StatelessWidget {
  final String      text;
  final ColorScheme scheme;
  final bool        isDark;
  const _SystemMessage({required this.text, required this.scheme, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: scheme.primary.withOpacity(0.2))),
          const SizedBox(width: 12),
          Flexible(
            child: MarkdownBody(
              data: text,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: scheme.primary.withOpacity(0.8),
                    fontSize: 12, fontStyle: FontStyle.italic),
                strong: TextStyle(color: scheme.primary,
                    fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: scheme.primary.withOpacity(0.2))),
        ],
      ),
    );
  }
}

class _StudentBubble extends StatelessWidget {
  final String      text;
  final ColorScheme scheme;
  const _StudentBubble({required this.text, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft:     Radius.circular(18),
            topRight:    Radius.circular(18),
            bottomLeft:  Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
      ),
    );
  }
}

class _LecturerBubble extends StatelessWidget {
  final String      text;
  final ColorScheme scheme;
  final bool        isDark;
  final bool        isFeedback;
  const _LecturerBubble({
    required this.text,
    required this.scheme,
    required this.isDark,
    required this.isFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Lecturer avatar
          Container(
            width: 36, height: 36,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kAccent, _kAccentL],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.school_rounded,
                color: Colors.white, size: 18),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFeedback ? 'AI Lecturer — Feedback' : 'AI Lecturer',
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF252525)
                        : const Color(0xFFF0F4FF),
                    borderRadius: const BorderRadius.only(
                      topLeft:     Radius.circular(4),
                      topRight:    Radius.circular(18),
                      bottomLeft:  Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(
                        color: scheme.primary.withOpacity(0.1)),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: MarkdownBody(
                    data: text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.87)
                            : Colors.black87,
                        fontSize: 14, height: 1.6,
                      ),
                      h1: TextStyle(color: isDark ? Colors.white : Colors.black87,
                          fontSize: 18, fontWeight: FontWeight.bold),
                      h2: TextStyle(color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16, fontWeight: FontWeight.bold),
                      h3: TextStyle(color: isDark ? Colors.white : Colors.black87,
                          fontSize: 15, fontWeight: FontWeight.w600),
                      strong: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold),
                      em: TextStyle(
                          color: isDark
                              ? Colors.white.withOpacity(0.87)
                              : Colors.black87,
                          fontStyle: FontStyle.italic),
                      code: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        backgroundColor: isDark
                            ? const Color(0xFF1A1A1A)
                            : const Color(0xFFE0E8FF),
                        color: isDark ? const Color(0xFF82B1FF) : _kAccent,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1A1A1A)
                            : const Color(0xFFE0E8FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      codeblockPadding: const EdgeInsets.all(12),
                      blockquote: TextStyle(
                          color: isDark
                              ? Colors.white.withOpacity(0.6)
                              : Colors.black54,
                          fontStyle: FontStyle.italic),
                      listBullet: TextStyle(
                          color: isDark
                              ? Colors.white.withOpacity(0.87)
                              : Colors.black87),
                      h1Padding: const EdgeInsets.only(top: 8, bottom: 4),
                      h2Padding: const EdgeInsets.only(top: 6, bottom: 3),
                      h3Padding: const EdgeInsets.only(top: 4, bottom: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// Utility widgets
// ══════════════════════════════════════════════════════════════════════════════

class _LevelPicker extends StatelessWidget {
  final String          selected;
  final void Function(String) onSelect;
  const _LevelPicker({required this.selected, required this.onSelect});

  static const _levels = [
    ('beginner',     'Beginner',     'Simple language\nEveryday examples'),
    ('intermediate', 'Intermediate', 'Balanced depth\nTechnical terms'),
    ('advanced',     'Advanced',     'Full theory\nPrecise language'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: _levels.map((l) {
        final isSelected = selected == l.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(l.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? _kAccent
                    : isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isSelected
                        ? _kAccent
                        : _kAccent.withOpacity(0.2),
                    width: isSelected ? 2 : 1),
              ),
              child: Column(
                children: [
                  Text(l.$2,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : scheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 4),
                  Text(l.$3,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white70
                            : scheme.onSurface.withOpacity(0.5),
                        fontSize: 10,
                        height: 1.4,
                      )),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  final String      label;
  final ColorScheme scheme;
  const _LoadingBar({required this.label, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: scheme.primary.withOpacity(0.05),
      child: Row(
        children: [
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: scheme.primary),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: scheme.primary, fontSize: 12,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String      error;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.error, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(error,
                style: const TextStyle(color: Colors.red, fontSize: 13))),
        GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                color: Colors.red, size: 16)),
      ]),
    );
  }
}
