// lib/screens/lecturer/ai_lecturer_screen.dart
//
// AI Lecturer — Phase 4: Persistent progress, post-lesson Q&A,
// "I don't know" handling, optional custom topics, and a final exam.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/lecturer_model.dart';
import '../../providers/lecturer_provider.dart';
import '../../providers/ai_provider.dart';
import '../../widgets/premium_gate.dart';
import '../../widgets/ai_message_content.dart';

// ── Brand colour ─────────────────────────────────────────────────────────────
const _kAccent  = Color(0xFF6C63FF);
const _kAccentL = Color(0xFF8B85FF);
const _kGreen   = Color(0xFF4CAF50);
const _kRed     = Color(0xFFE53935);

// ══════════════════════════════════════════════════════════════════════════════
// Entry point
// ══════════════════════════════════════════════════════════════════════════════

class AiLecturerScreen extends StatelessWidget {
  const AiLecturerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LecturerProvider>(
      builder: (ctx, prov, _) {
        if (prov.hasSession) return const _SessionScreen();
        return const _EntryScreen();
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Entry Screen — resume list + "Start New Course"
// ══════════════════════════════════════════════════════════════════════════════

class _EntryScreen extends StatefulWidget {
  const _EntryScreen();
  @override
  State<_EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<_EntryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LecturerProvider>().loadHomeData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov   = context.watch<LecturerProvider>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Lecturer'),
        centerTitle: true,
      ),
      body: prov.loadingHome
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => prov.loadHomeData(),
              child: CustomScrollView(
                slivers: [
                  // ── Hero banner ────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_kAccent, _kAccentL],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🎓', style: TextStyle(fontSize: 36)),
                          const SizedBox(height: 8),
                          const Text('AI Lecturer',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          const Text(
                            'Full-course structured teaching, chapter by chapter.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _goSetup(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: _kAccent,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Start New Course',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── My Courses ─────────────────────────────────────────────
                  if (prov.savedCourses.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Text('📚 My Courses',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: scheme.onSurface)),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _SavedCourseTile(
                          course: prov.savedCourses[i],
                          onResume: () => _resume(context, prov.savedCourses[i].id),
                          onDelete: () => _confirmDelete(
                              context, prov, prov.savedCourses[i]),
                        ),
                        childCount: prov.savedCourses.length,
                      ),
                    ),
                  ],

                  // ── Popular Courses ────────────────────────────────────────
                  if (prov.popularCourses.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Text('🔥 Popular Courses',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: scheme.onSurface)),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 2.6,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final pc = prov.popularCourses[i];
                            return GestureDetector(
                              onTap: () => _goSetupWith(context, pc),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.07)
                                      : _kAccent.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: _kAccent.withOpacity(0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (pc.courseCode != null)
                                      Text(pc.courseCode!,
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: _kAccent)),
                                    Text(pc.courseName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: scheme.onSurface)),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: prov.popularCourses.length,
                        ),
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
    );
  }

  void _goSetup(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const _SetupScreen()));
  }

  void _goSetupWith(BuildContext context, PopularCourse pc) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _SetupScreen(
                  prefilledName: pc.courseName,
                  prefilledCode: pc.courseCode,
                )));
  }

  void _resume(BuildContext context, int courseId) {
    context.read<LecturerProvider>().resumeCourse(courseId);
  }

  void _confirmDelete(
      BuildContext context, LecturerProvider prov, LecturerCourseSummary c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Course?'),
        content: Text('Remove "${c.courseName}" and all progress?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              prov.deleteSavedCourse(c.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Saved course tile ─────────────────────────────────────────────────────────

class _SavedCourseTile extends StatelessWidget {
  final LecturerCourseSummary course;
  final VoidCallback          onResume;
  final VoidCallback          onDelete;
  const _SavedCourseTile(
      {required this.course, required this.onResume, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final scheme   = Theme.of(context).colorScheme;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final pct      = course.progressPercent.round();
    final done     = course.status == 'completed';
    final accentFg = done ? _kGreen : _kAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onResume,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: accentFg.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(done ? '✅' : '📖',
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                // Title + progress
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.courseName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: scheme.onSurface)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (course.courseCode != null &&
                              course.courseCode!.isNotEmpty) ...[
                            Text(course.courseCode!,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: accentFg)),
                            const Text(' · ',
                                style: TextStyle(color: Colors.grey)),
                          ],
                          Text(_levelLabel(course.level),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: course.progressPercent / 100,
                          backgroundColor: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.1),
                          color: accentFg,
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text('$pct% complete',
                          style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : Colors.black45)),
                    ],
                  ),
                ),
                // Actions
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        done
                            ? Icons.check_circle_rounded
                            : Icons.play_circle_rounded,
                        color: accentFg,
                        size: 22),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _levelLabel(String l) {
    switch (l) {
      case 'beginner':  return '🟢 Beginner';
      case 'advanced':  return '🔴 Advanced';
      default:          return '🟡 Intermediate';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Setup Screen — course name, code, level, optional custom topics
// ══════════════════════════════════════════════════════════════════════════════

class _SetupScreen extends StatefulWidget {
  final String?  prefilledName;
  final String?  prefilledCode;
  const _SetupScreen({this.prefilledName, this.prefilledCode});

  @override
  State<_SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<_SetupScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _codeCtrl  = TextEditingController();
  final _topicsCtrl = TextEditingController();
  String _level    = 'intermediate';
  bool   _showTopics = false;

  static const _levels = [
    ('beginner',     '🟢 Beginner',     'Simple explanations, real-world analogies'),
    ('intermediate', '🟡 Intermediate', 'Core theory + worked examples'),
    ('advanced',     '🔴 Advanced',      'Technical depth, edge cases, research'),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.prefilledName ?? '';
    _codeCtrl.text = widget.prefilledCode ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _codeCtrl.dispose(); _topicsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov   = context.watch<LecturerProvider>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final busy   = prov.state == LecturerState.loadingCurriculum;

    return Scaffold(
      appBar: AppBar(title: const Text('New Course'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course name
              _Label('Course Name *'),
              const SizedBox(height: 6),
              TextFormField(
                controller:  _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDec(context, 'e.g. Artificial Intelligence'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Course name is required' : null,
              ),

              const SizedBox(height: 16),

              // Course code
              _Label('Course Code (optional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDec(context, 'e.g. COSC 208'),
              ),

              const SizedBox(height: 20),

              // Level
              _Label('Explanation Level'),
              const SizedBox(height: 8),
              Column(
                children: _levels.map((l) {
                  final selected = l.$1 == _level;
                  return GestureDetector(
                    onTap: () => setState(() => _level = l.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected
                            ? _kAccent.withOpacity(0.12)
                            : (isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? _kAccent : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(l.$1[0].toUpperCase() + l.$1.substring(1),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: selected
                                      ? _kAccent
                                      : scheme.onSurface)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(l.$3,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54)),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle_rounded,
                                color: _kAccent, size: 20),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Custom topics (optional, expandable)
              GestureDetector(
                onTap: () => setState(() => _showTopics = !_showTopics),
                child: Row(
                  children: [
                    Icon(_showTopics
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                        color: _kAccent, size: 20),
                    const SizedBox(width: 6),
                    Text('Custom Topics (optional)',
                        style: TextStyle(
                            color: _kAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ],
                ),
              ),

              if (_showTopics) ...[
                const SizedBox(height: 8),
                Text(
                  'List specific topics you want the AI to cover, separated '
                  'by commas or one per line. Leave blank for the AI to '
                  'auto-generate a full curriculum.',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _topicsCtrl,
                  maxLines: 4,
                  decoration: _inputDec(context,
                      'e.g. Searching algorithms, Sorting algorithms, Big O Notation...'),
                ),
              ],

              const SizedBox(height: 28),

              // Error
              if (prov.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: _kRed.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(prov.error!,
                      style: const TextStyle(color: _kRed, fontSize: 13)),
                ),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _kAccent.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: busy
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.school_rounded),
                  label: Text(
                    busy ? 'Generating curriculum…' : 'Start Course',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    prov.clearError();
    if (!_formKey.currentState!.validate()) return;

    List<String>? customTopics;
    if (_showTopics && _topicsCtrl.text.trim().isNotEmpty) {
      customTopics = _topicsCtrl.text
          .split(RegExp(r'[,\n]'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
    }

    context.read<LecturerProvider>()
      ..setSession(
        courseName: _nameCtrl.text.trim(),
        courseCode: _codeCtrl.text.trim(),
        level:      _level,
      )
      ..startNewCourse(customTopics: customTopics);

    Navigator.pop(context);   // close setup; AiLecturerScreen switches to _SessionScreen
  }

  LecturerProvider get prov => context.read<LecturerProvider>();

  InputDecoration _inputDec(BuildContext ctx, String hint) => InputDecoration(
    hintText:      hint,
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75)));
}

// ══════════════════════════════════════════════════════════════════════════════
// Session Screen — chapter list drawer + chat-style message area
// ══════════════════════════════════════════════════════════════════════════════

class _SessionScreen extends StatefulWidget {
  const _SessionScreen();
  @override
  State<_SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<_SessionScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() { _scrollCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final prov   = context.watch<LecturerProvider>();
    final scheme = Theme.of(context).colorScheme;

    // Auto-scroll to bottom when messages change.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    final isLoading = prov.state == LecturerState.loadingCurriculum ||
        prov.state == LecturerState.loadingLesson;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(prov.courseName,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
            Text(_levelLabel(prov.level),
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _confirmExit(context, prov),
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_book_rounded),
              tooltip: 'Chapter list',
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: _ChapterDrawer(prov: prov),
      body: isLoading && prov.messages.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _kAccent),
                  SizedBox(height: 16),
                  Text('Generating your curriculum…',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : Column(
              children: [
                // Progress bar
                _ProgressBar(prov: prov),

                // Messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: prov.messages.length,
                    itemBuilder: (_, i) => _MessageTile(
                        msg: prov.messages[i]),
                  ),
                ),

                // Loading shimmer for active AI call
                if (prov.state == LecturerState.loadingLesson  ||
                    prov.state == LecturerState.qaLoading       ||
                    prov.state == LecturerState.checking        ||
                    prov.state == LecturerState.examLoading     ||
                    prov.state == LecturerState.examGrading)
                  const _ThinkingIndicator(),

                // Error banner
                if (prov.error != null)
                  _ErrorBanner(
                    error: prov.error!,
                    onDismiss: prov.clearError,
                  ),

                // Action area
                _ActionArea(prov: prov),
              ],
            ),
    );
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve:    Curves.easeOut,
      );
    }
  }

  void _confirmExit(BuildContext context, LecturerProvider prov) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Exit Course?'),
        content: const Text(
            'Your progress is saved. You can resume this course anytime '
            'from the AI Lecturer home screen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep Learning')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              prov.reset();
            },
            child: const Text('Exit', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  String _levelLabel(String l) {
    switch (l) {
      case 'beginner':  return '🟢 Beginner';
      case 'advanced':  return '🔴 Advanced';
      default:          return '🟡 Intermediate';
    }
  }
}

// ── Progress bar ─────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final LecturerProvider prov;
  const _ProgressBar({required this.prov});

  @override
  Widget build(BuildContext context) {
    final passed  = prov.chapters.where((c) => c.isPassed).length;
    final total   = prov.chapters.length;
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 36,
      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Text('Chapter ${prov.currentIndex + 1} / $total',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54)),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: total > 0 ? passed / total : 0,
                backgroundColor: (isDark ? Colors.white : Colors.black)
                    .withOpacity(0.1),
                color: _kAccent,
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$passed/$total done',
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black45)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Action Area — everything below the message list (buttons + input)
// ══════════════════════════════════════════════════════════════════════════════

class _ActionArea extends StatefulWidget {
  final LecturerProvider prov;
  const _ActionArea({required this.prov});

  @override
  State<_ActionArea> createState() => _ActionAreaState();
}

class _ActionAreaState extends State<_ActionArea> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  LecturerProvider get prov => widget.prov;
  bool get _busy => prov.state != LecturerState.idle &&
      prov.state != LecturerState.error;

  @override
  Widget build(BuildContext context) {
    final phase        = prov.currentChapter?.phase;
    final entitlements = context.watch<AiProvider>().entitlements;

    // ── Premium gate: chapter locked ────────────────────────────────────────
    final chapterIdx = prov.currentChapter?.chapter.index ?? 1;
    if (entitlements.isLecturerChapterLocked(chapterIdx)) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: PremiumGate(feature: PremiumFeature.lecturerChapters),
      );
    }

    // ── Premium gate: exam locked ────────────────────────────────────────────
    if (prov.courseStage == CourseStage.examOffer &&
        !entitlements.canTakeLecturerExam) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: PremiumGate(feature: PremiumFeature.lecturerExam),
      );
    }

    // ── Exam offer ──────────────────────────────────────────────────────────
    if (prov.courseStage == CourseStage.examOffer) {
      return _ChoiceButtons(
        question: 'Would you like to take the final exam?',
        yesLabel: '📝 Take Exam',
        noLabel:  '🏁 Finish Course',
        onYes: () => prov.respondToExamOffer(true),
        onNo:  () => prov.respondToExamOffer(false),
        busy:  _busy,
      );
    }

    // ── Exam in progress ────────────────────────────────────────────────────
    if (prov.courseStage == CourseStage.examInProgress &&
        prov.examQuestions.isNotEmpty) {
      return _ExamAnswerArea(prov: prov);
    }

    // ── Exam result ─────────────────────────────────────────────────────────
    if (prov.courseStage == CourseStage.examResult) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: double.infinity,
          child: _AccentButton(
            label: '🎓 View Full Results',
            onTap: () => _showResultSheet(context, prov.examResult!),
          ),
        ),
      );
    }

    // ── Course completed (no exam) ──────────────────────────────────────────
    if (prov.courseStage == CourseStage.completed) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: double.infinity,
          child: _AccentButton(
            label: '🏠 Back to Courses',
            onTap: prov.reset,
          ),
        ),
      );
    }

    // ── Not started yet ─────────────────────────────────────────────────────
    if (prov.curriculum != null && prov.chapters.isNotEmpty &&
        prov.currentChapter!.phase == ChapterPhase.notStarted &&
        prov.currentChapter!.lessonText == null) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: double.infinity,
          child: _AccentButton(
            label: '▶ Start Chapter ${prov.currentChapter!.chapter.index}',
            onTap: _busy ? null : () => prov.loadChapter(prov.currentIndex),
          ),
        ),
      );
    }

    // ── Q&A choice: "Do you have any questions?" ────────────────────────────
    if (phase == ChapterPhase.awaitingQaChoice) {
      return _ChoiceButtons(
        question: null,
        yesLabel: '❓ I have a question',
        noLabel:  '✅ No, continue',
        onYes: () => prov.answerQaChoice(true),
        onNo:  () => prov.answerQaChoice(false),
        busy:  _busy,
      );
    }

    // ── Q&A: waiting for student question ───────────────────────────────────
    if (phase == ChapterPhase.awaitingQaQuestion) {
      return _TextInput(
        ctrl:       _ctrl,
        hint:       'Type your question…',
        submitLabel: 'Ask',
        busy:       _busy,
        onSubmit: (q) {
          prov.submitQaQuestion(q);
          _ctrl.clear();
        },
      );
    }

    // ── Check question: waiting for answer ──────────────────────────────────
    if (phase == ChapterPhase.awaitingCheckAnswer) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TextInput(
            ctrl:       _ctrl,
            hint:       'Type your answer…',
            submitLabel: 'Submit',
            busy:       _busy,
            onSubmit: (a) {
              prov.submitCheckAnswer(a);
              _ctrl.clear();
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => prov.submitCheckAnswer('', knowsAnswer: false),
                child: const Text('🤷 I don\'t know',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          ),
        ],
      );
    }

    // ── Feedback shown → "Next Chapter" ─────────────────────────────────────
    if (phase == ChapterPhase.feedbackShown) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: double.infinity,
          child: _AccentButton(
            label: prov.isLastChapter
                ? '🎓 Complete Course'
                : '➡ Next Chapter',
            onTap: _busy ? null : prov.advanceToNextChapter,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showResultSheet(BuildContext context, ExamResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExamResultSheet(result: result),
    );
  }
}

// ── Shared UI atoms ───────────────────────────────────────────────────────────

class _AccentButton extends StatelessWidget {
  final String    label;
  final VoidCallback? onTap;
  const _AccentButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: _kAccent,
      foregroundColor: Colors.white,
      disabledBackgroundColor: _kAccent.withOpacity(0.4),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: Text(label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
  );
}

class _ChoiceButtons extends StatelessWidget {
  final String?  question;
  final String   yesLabel;
  final String   noLabel;
  final VoidCallback onYes;
  final VoidCallback onNo;
  final bool     busy;
  const _ChoiceButtons({
    required this.yesLabel, required this.noLabel,
    required this.onYes, required this.onNo, required this.busy,
    this.question,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: busy ? null : onYes,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _kAccent.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(yesLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: busy ? null : onNo,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey,
                side: const BorderSide(color: Colors.grey),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(noLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String   hint;
  final String   submitLabel;
  final bool     busy;
  final void Function(String) onSubmit;
  const _TextInput({
    required this.ctrl, required this.hint, required this.submitLabel,
    required this.busy, required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: hint,
                filled:   true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.07)
                    : Colors.grey.shade100,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _kAccent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: busy
                  ? null
                  : () {
                      final t = ctrl.text.trim();
                      if (t.isNotEmpty) onSubmit(t);
                    },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: busy
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Exam answer area
// ══════════════════════════════════════════════════════════════════════════════

class _ExamAnswerArea extends StatefulWidget {
  final LecturerProvider prov;
  const _ExamAnswerArea({required this.prov});
  @override
  State<_ExamAnswerArea> createState() => _ExamAnswerAreaState();
}

class _ExamAnswerAreaState extends State<_ExamAnswerArea> {
  late final Map<int, TextEditingController> _ctrls;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final q in widget.prov.examQuestions)
        q.id: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov   = widget.prov;
    final busy   = prov.state == LecturerState.examGrading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
            top: BorderSide(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.1))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Text('📝 Answer all questions, then submit',
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              itemCount: prov.examQuestions.length,
              itemBuilder: (_, i) {
                final q = prov.examQuestions[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Q${q.id}. ${q.question}',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: scheme.onSurface)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _ctrls[q.id],
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Your answer…',
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.grey.shade100,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: busy || _submitted
                    ? null
                    : () {
                        final answers = <int, String>{
                          for (final e in _ctrls.entries)
                            e.key: e.value.text.trim(),
                        };
                        setState(() => _submitted = true);
                        prov.submitExam(answers);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kAccent.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                label: Text(busy ? 'Grading…' : 'Submit Exam',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Exam result bottom sheet
// ══════════════════════════════════════════════════════════════════════════════

class _ExamResultSheet extends StatelessWidget {
  final ExamResult result;
  const _ExamResultSheet({required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final scheme  = Theme.of(context).colorScheme;
    final pct     = result.total > 0
        ? (result.score / result.total * 100).round()
        : 0;
    final color   = pct >= 70
        ? _kGreen
        : pct >= 50 ? Colors.orange : _kRed;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2)),
            ),

            // Score badge
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Center(
                child: Text('$pct%',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ),
            ),
            const SizedBox(height: 8),
            Text('${result.score.toStringAsFixed(1)} / ${result.total} correct',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(result.overallFeedback,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black54)),
            ),
            const SizedBox(height: 16),

            // Per-question breakdown
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: result.results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final r = result.results[i];
                  final verdictColor = r.verdict == 'correct'
                      ? _kGreen
                      : r.verdict == 'partial' ? Colors.orange : _kRed;
                  final icon = r.verdict == 'correct'
                      ? '✅' : r.verdict == 'partial' ? '⚠️' : '❌';
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: verdictColor.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('$icon Q${r.id}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: verdictColor)),
                          const Spacer(),
                          Text(r.verdict.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: verdictColor)),
                        ]),
                        const SizedBox(height: 4),
                        Text(r.feedback,
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black54)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Chapter list drawer
// ══════════════════════════════════════════════════════════════════════════════

class _ChapterDrawer extends StatelessWidget {
  final LecturerProvider prov;
  const _ChapterDrawer({required this.prov});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final scheme  = Theme.of(context).colorScheme;
    final entitlements = context.watch<AiProvider>().entitlements;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Course Chapters',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: scheme.onSurface)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: prov.chapters.length,
                itemBuilder: (_, i) {
                  final cp        = prov.chapters[i];
                  final isCurrent = i == prov.currentIndex;
                  final locked    = cp.isLocked;
                  final done      = cp.isPassed;
                  // Premium gate — inactive while LECTURER_GATED = false
                  final premiumLocked = entitlements
                      .isLecturerChapterLocked(cp.chapter.index);

                  Color fg = (locked || premiumLocked)
                      ? Colors.grey
                      : isCurrent ? _kAccent : scheme.onSurface;
                  IconData ico = premiumLocked
                      ? Icons.lock_rounded
                      : locked
                          ? Icons.lock_outline_rounded
                          : done
                              ? Icons.check_circle_rounded
                              : isCurrent
                                  ? Icons.menu_book_rounded
                                  : Icons.circle_outlined;
                  Color icoColor = premiumLocked
                      ? const Color(0xFF6C63FF)
                      : done
                          ? _kGreen
                          : isCurrent ? _kAccent : Colors.grey;

                  return ListTile(
                    leading: Icon(ico, color: icoColor, size: 20),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${cp.chapter.index}. ${cp.chapter.title}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: fg),
                          ),
                        ),
                        if (premiumLocked)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: PremiumChapterLockBadge(),
                          ),
                      ],
                    ),
                    subtitle: locked
                        ? null
                        : Text(cp.chapter.durationEstimate,
                            style: const TextStyle(fontSize: 11)),
                    dense: true,
                    tileColor: isCurrent
                        ? _kAccent.withOpacity(0.1)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    onTap: (locked || premiumLocked)
                        ? null
                        : () {
                            Navigator.pop(context);
                            if (i != prov.currentIndex) {
                              prov.loadChapter(i);
                            }
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Message tiles
// ══════════════════════════════════════════════════════════════════════════════

class _MessageTile extends StatelessWidget {
  final LecturerMessage msg;
  const _MessageTile({required this.msg});

  @override
  Widget build(BuildContext context) {
    switch (msg.type) {
      case LecturerMessageType.system:
        return _SystemMessage(text: msg.text);
      case LecturerMessageType.studentAnswer:
        return _StudentBubble(text: msg.text);
      case LecturerMessageType.lesson:
      case LecturerMessageType.feedback:
        return _LecturerBubble(text: msg.text);
    }
  }
}

class _SystemMessage extends StatelessWidget {
  final String text;
  const _SystemMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _kAccent.withOpacity(0.2)),
      ),
      child: AiMessageContent(
        data: text,
        isDark: isDark,
      ),
    );
  }
}

class _StudentBubble extends StatelessWidget {
  final String text;
  const _StudentBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _kAccent,
          borderRadius: const BorderRadius.only(
            topLeft:     Radius.circular(16),
            topRight:    Radius.circular(4),
            bottomLeft:  Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
      ),
    );
  }
}

class _LecturerBubble extends StatelessWidget {
  final String text;
  const _LecturerBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34, height: 34,
          margin: const EdgeInsets.only(right: 8, top: 4),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Center(
              child: Text('🎓', style: TextStyle(fontSize: 16))),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF252540)
                  : const Color(0xFFF0EFFF),
              borderRadius: const BorderRadius.only(
                topLeft:     Radius.circular(4),
                topRight:    Radius.circular(16),
                bottomLeft:  Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: AiMessageContent(
              data: text,
              isDark: isDark,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Thinking indicator ─────────────────────────────────────────────────────────

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.15), shape: BoxShape.circle),
            child: const Center(
                child: Text('🎓', style: TextStyle(fontSize: 14))),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252540) : const Color(0xFFF0EFFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const SizedBox(
              width: 40, height: 10,
              child: LinearProgressIndicator(
                  color: _kAccent, backgroundColor: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String       error;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.error, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: _kRed.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _kRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(error,
                  style: const TextStyle(color: _kRed, fontSize: 12))),
          GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close, color: _kRed, size: 18)),
        ],
      ),
    );
  }
}
