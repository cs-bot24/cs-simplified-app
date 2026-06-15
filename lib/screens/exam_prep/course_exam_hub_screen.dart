// lib/screens/exam_prep/course_exam_hub_screen.dart
//
// Per-course Exam Preparation Hub — the action centre for one course.
// Contains: Materials list, Practice Questions, Quiz Me,
//           Quick Revision Notes, Exam Focus Areas, Ask AI.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../models/exam_prep_model.dart';
import '../../models/material_model.dart';
import '../../models/ai_model.dart';
import '../../providers/ai_provider.dart';
import '../../screens/pdf/pdf_viewer_screen.dart';
import '../../screens/ai/ai_tutor_screen.dart';

const _kAmber  = Color(0xFFD97706);
const _kAmberL = Color(0xFFB45309);
const _kGreen  = Color(0xFF4CAF50);
const _kRed    = Color(0xFFE53935);

// ══════════════════════════════════════════════════════════════════════════════
// Course Exam Hub
// ══════════════════════════════════════════════════════════════════════════════

class CourseExamHubScreen extends StatelessWidget {
  final ExamCourse course;
  const CourseExamHubScreen({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final scheme  = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Sticky amber header ────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: _kAmberL,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kAmberL, _kAmber],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 90, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.courseCode,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(course.courseTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                        '${course.materialCount} material${course.materialCount == 1 ? '' : 's'} available',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── AI Action Buttons ─────────────────────────────────
                  _SectionHeader('🚀 Exam Tools'),
                  const SizedBox(height: 10),
                  _ActionGrid(course: course),

                  const SizedBox(height: 24),

                  // ── Materials list ────────────────────────────────────
                  _SectionHeader(
                      '📄 Available Materials (${course.materialCount})'),
                  const SizedBox(height: 10),
                  ...course.materials.map(
                      (m) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _MaterialTile(
                                material: m,
                                courseCode: course.courseCode),
                          )),

                  // ── Phase 3 reserved slot (Readiness Tracker) ─────────
                  // ── Readiness Tracker ─────────────────────────────────
                  _ExamReadinessCard(course: course),
                  const SizedBox(height: 12),

                  // ── Exam Countdown ────────────────────────────────────
                  _ExamCountdownCard(course: course),
                  const SizedBox(height: 20),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurface),
      );
}

// ── Action grid ───────────────────────────────────────────────────────────────

class _ActionGrid extends StatelessWidget {
  final ExamCourse course;
  const _ActionGrid({required this.course});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionDef(
        emoji: '📝',
        label: 'Practice\nQuestions',
        color: const Color(0xFF3B82F6),
        onTap: () => _push(context, _PracticeQuestionsScreen(course: course)),
      ),
      _ActionDef(
        emoji: '⏱',
        label: 'Quiz\nMe',
        color: const Color(0xFF8B5CF6),
        onTap: () => _push(context, _QuizSetupScreen(course: course)),
      ),
      _ActionDef(
        emoji: '📖',
        label: 'Quick\nRevision',
        color: const Color(0xFF10B981),
        onTap: () => _push(context, _RevisionNotesScreen(course: course)),
      ),
      _ActionDef(
        emoji: '🎯',
        label: 'Exam\nFocus',
        color: const Color(0xFFEF4444),
        onTap: () => _push(context, _FocusAreasScreen(course: course)),
      ),
      _ActionDef(
        emoji: '🤖',
        label: 'Ask AI\nAbout This',
        color: _kAmberL,
        onTap: () => _openCourseAI(context),
        wide: true,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (_, i) {
        final a = actions[i];
        // "Ask AI" spans full width if it's the last odd item
        if (a.wide && actions.length % 2 != 0 && i == actions.length - 1) {
          return GridView.count(
            shrinkWrap: true,
            crossAxisCount: 1,
            childAspectRatio: 3.5,
            physics: const NeverScrollableScrollPhysics(),
            children: [_ActionCard(def: a)],
          );
        }
        return _ActionCard(def: a);
      },
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _openCourseAI(BuildContext context) {
    // Pre-seed the AI provider with course context + exam_prep mode
    final ai = context.read<AiProvider>();
    ai.setMode(AiMode.examPrep);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AiTutorScreen(),
        // Pass course context via the route — AiTutorScreen uses AiProvider
        // which we just set. The AI will automatically answer in exam_prep mode
        // scoped to this course.
      ),
    ).then((_) {
      // Reset mode when returning so normal AI stays unaffected
      if (context.mounted) ai.setMode(AiMode.normal);
    });
  }
}

class _ActionDef {
  final String      emoji;
  final String      label;
  final Color       color;
  final VoidCallback onTap;
  final bool        wide;
  const _ActionDef({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
    this.wide = false,
  });
}

class _ActionCard extends StatelessWidget {
  final _ActionDef def;
  const _ActionCard({required this.def});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark
          ? def.color.withOpacity(0.15)
          : def.color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: def.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: def.color.withOpacity(0.25)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(def.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 6),
              Text(def.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: def.color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Material tile ─────────────────────────────────────────────────────────────

class _MaterialTile extends StatelessWidget {
  final MaterialModel material;
  final String        courseCode;
  const _MaterialTile({required this.material, required this.courseCode});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Track silently for readiness
          ApiClient.trackExamActivity(
            courseCode: courseCode,
            activity:   'material_read',
          ).catchError((_) {});
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfViewerScreen(
                url:        material.fileUrl,
                title:      material.materialTitle,
                materialId: material.id,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kAmber.withOpacity(0.15)),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _kAmber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded,
                  color: _kAmber, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(material.materialTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: Colors.grey[400]),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Practice Questions Screen
// ══════════════════════════════════════════════════════════════════════════════

class _PracticeQuestionsScreen extends StatefulWidget {
  final ExamCourse course;
  const _PracticeQuestionsScreen({required this.course});

  @override
  State<_PracticeQuestionsScreen> createState() =>
      _PracticeQuestionsScreenState();
}

class _PracticeQuestionsScreenState extends State<_PracticeQuestionsScreen> {
  int     _count     = 10;
  bool    _loading   = false;
  String? _content;
  String? _error;

  static const _countOptions = [10, 20, 50];

  Future<void> _generate() async {
    setState(() { _loading = true; _error = null; _content = null; });
    try {
      final data = await ApiClient.getExamPracticeQuestions(
        courseCode:  widget.course.courseCode,
        courseTitle: widget.course.courseTitle,
        count:       _count,
      );
      setState(() { _content = data['content'] as String; _loading = false; });
    } catch (_) {
      setState(() {
        _error = 'Could not generate questions. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice Questions'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
      ),
      body: _content != null
          ? _ResultView(
              title: '${widget.course.courseCode} — $_count Questions',
              content: _content!,
              accentColor: const Color(0xFF3B82F6),
              onRegenerate: () => setState(() => _content = null),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Course badge
                  _CourseBadge(course: widget.course, color: const Color(0xFF3B82F6)),
                  const SizedBox(height: 24),

                  const Text('How many questions?',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 12),

                  Row(
                    children: _countOptions.map((n) {
                      final selected = n == _count;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _count = n),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF3B82F6)
                                    : (isDark
                                        ? Colors.white.withOpacity(0.07)
                                        : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: selected
                                        ? const Color(0xFF3B82F6)
                                        : Colors.transparent,
                                    width: 2),
                              ),
                              child: Text('$n',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                      color: selected
                                          ? Colors.white
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 8),
                  Text('Questions will include MCQ, short answer, and theory.',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45)),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBox(_error!),
                  ],

                  const Spacer(),
                  _GenerateButton(
                    label: 'Generate $_count Questions',
                    color: const Color(0xFF3B82F6),
                    loading: _loading,
                    onTap: _generate,
                  ),
                ],
              ),
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Quiz Setup + Quiz Screen
// ══════════════════════════════════════════════════════════════════════════════

class _QuizSetupScreen extends StatefulWidget {
  final ExamCourse course;
  const _QuizSetupScreen({required this.course});
  @override
  State<_QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<_QuizSetupScreen> {
  int     _count   = 20;
  bool    _loading = false;
  String? _error;

  static const _options = [10, 20, 30];

  Future<void> _startQuiz() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.getExamQuiz(
        courseCode:  widget.course.courseCode,
        courseTitle: widget.course.courseTitle,
        count:       _count,
      );
      final raw    = jsonDecode(data['quiz_json'] as String) as Map<String, dynamic>;
      final quiz   = QuizData.fromJson(raw);
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => _QuizScreen(
            quiz: quiz, course: widget.course)),
      );
    } catch (_) {
      setState(() {
        _error = 'Could not generate quiz. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFF8B5CF6);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Me'),
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CourseBadge(course: widget.course, color: accent),
            const SizedBox(height: 24),

            const Text('Number of questions',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),

            Row(
              children: _options.map((n) {
                final selected = n == _count;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _count = n),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? accent
                              : (isDark
                                  ? Colors.white.withOpacity(0.07)
                                  : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: selected ? accent : Colors.transparent,
                              width: 2),
                        ),
                        child: Text('$n',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: selected
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.timer_outlined, color: accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Estimated time: ${(_count * 0.75).round()} minutes\n'
                    'All multiple choice — tap to select your answer.',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              ]),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              _ErrorBox(_error!),
            ],

            const Spacer(),
            _GenerateButton(
              label: 'Start $_count-Question Quiz',
              color: accent,
              loading: _loading,
              onTap: _startQuiz,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Live quiz screen ──────────────────────────────────────────────────────────

class _QuizScreen extends StatefulWidget {
  final QuizData   quiz;
  final ExamCourse course;
  const _QuizScreen({required this.quiz, required this.course});

  @override
  State<_QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<_QuizScreen> {
  int          _current    = 0;
  bool         _submitted  = false;
  late Timer   _timer;
  int          _secondsLeft = 0;

  static const _accentColor = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    // 45 seconds per question
    _secondsLeft = widget.quiz.total * 45;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 0) {
        _timer.cancel();
        if (!_submitted) _submit();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  QuizQuestion get _q => widget.quiz.questions[_current];

  String get _timeLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _select(int idx) {
    if (_submitted) return;
    setState(() => _q.selectedIndex = idx);
  }

  void _next() {
    if (_current < widget.quiz.total - 1) {
      setState(() => _current++);
    } else {
      _submit();
    }
  }

  void _submit() {
    _timer.cancel();
    setState(() => _submitted = true);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => _QuizResultScreen(
          quiz: widget.quiz, course: widget.course)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final scheme    = Theme.of(context).colorScheme;
    final answered  = widget.quiz.answeredCount;
    final total     = widget.quiz.total;
    final pct       = total > 0 ? answered / total : 0.0;
    final isRed     = _secondsLeft < 60;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Text('Q${_current + 1}/$total',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isRed ? _kRed : Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(_timeLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ]),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _submit,
              child: const Text('Submit',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white24,
            color: Colors.white,
            minHeight: 4,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _accentColor.withOpacity(0.2)),
              ),
              child: Text(_q.question,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      height: 1.5)),
            ),
            const SizedBox(height: 18),

            // Options
            ...List.generate(_q.options.length, (i) {
              final selected = _q.selectedIndex == i;
              final letter   = ['A', 'B', 'C', 'D'][i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => _select(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected
                          ? _accentColor.withOpacity(0.12)
                          : (isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: selected
                              ? _accentColor
                              : (isDark
                                  ? Colors.white12
                                  : Colors.grey.shade200),
                          width: selected ? 2 : 1),
                    ),
                    child: Row(children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: selected ? _accentColor : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: selected
                                  ? _accentColor
                                  : Colors.grey.shade400),
                        ),
                        child: Center(
                          child: Text(letter,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? Colors.white : Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_q.options[i],
                            style: TextStyle(
                                fontSize: 14,
                                color: selected
                                    ? _accentColor
                                    : scheme.onSurface)),
                      ),
                    ]),
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),

            // Nav buttons
            Row(children: [
              if (_current > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _current--),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: _accentColor,
                        side: const BorderSide(color: _accentColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: const Text('← Prev'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text(
                      _current < total - 1 ? 'Next →' : 'Submit Quiz',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Quiz result screen ────────────────────────────────────────────────────────

class _QuizResultScreen extends StatefulWidget {
  final QuizData   quiz;
  final ExamCourse course;
  const _QuizResultScreen({required this.quiz, required this.course});

  @override
  State<_QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<_QuizResultScreen> {
  @override
  void initState() {
    super.initState();
    // Silently record quiz score for readiness tracking
    ApiClient.trackExamActivity(
      courseCode: widget.course.courseCode,
      activity:   'quiz',
      quizScore:  widget.quiz.scorePercent,
    ).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final quiz   = widget.quiz;
    final pct    = quiz.scorePercent;
    final color  = pct >= 70 ? _kGreen : pct >= 50 ? _kAmber : _kRed;
    final emoji  = pct >= 70 ? '🎉' : pct >= 50 ? '😊' : '💪';
    final msg    = pct >= 70
        ? 'Excellent! You\'re well prepared.'
        : pct >= 50
            ? 'Good effort! Review the wrong answers.'
            : 'Keep practising — you\'ll get there!';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Identify weak topics (wrong answers)
    final wrong = quiz.questions.where((q) => q.isAnswered && !q.isCorrect).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Result'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Score circle
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 28)),
                  Text('${pct.round()}%',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: color)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('${quiz.correctCount} / ${quiz.total} correct',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(msg,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54)),

            const SizedBox(height: 24),

            // Weak areas
            if (wrong.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text('⚠️ Review These (${wrong.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              const SizedBox(height: 10),
              ...wrong.map((q) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kRed.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kRed.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Q${q.id}. ${q.question}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 6),
                        Text(
                            '✅ Correct: ${q.options[q.correctIndex]}',
                            style: const TextStyle(
                                fontSize: 12, color: _kGreen,
                                fontWeight: FontWeight.w600)),
                        if (q.selectedIndex != null) ...[
                          const SizedBox(height: 2),
                          Text(
                              '❌ You chose: ${q.options[q.selectedIndex!]}',
                              style: const TextStyle(
                                  fontSize: 12, color: _kRed)),
                        ],
                        if (q.explanation.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(q.explanation,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54)),
                        ],
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
            ],

            // All correct answers (collapsed)
            ExpansionTile(
              title: const Text('All Answers',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              children: quiz.questions.map((q) {
                final correct = q.isCorrect;
                return ListTile(
                  dense: true,
                  leading: Text(correct ? '✅' : (q.isAnswered ? '❌' : '—')),
                  title: Text('Q${q.id}. ${q.question}',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      'Answer: ${q.options[q.correctIndex]}',
                      style: const TextStyle(
                          fontSize: 11, color: _kGreen,
                          fontWeight: FontWeight.w600)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Quick Revision Notes Screen
// ══════════════════════════════════════════════════════════════════════════════

class _RevisionNotesScreen extends StatefulWidget {
  final ExamCourse course;
  const _RevisionNotesScreen({required this.course});

  @override
  State<_RevisionNotesScreen> createState() => _RevisionNotesScreenState();
}

class _RevisionNotesScreenState extends State<_RevisionNotesScreen> {
  bool    _loading = false;
  String? _content;
  String? _error;

  static const _accent = Color(0xFF10B981);

  @override
  void initState() { super.initState(); _generate(); }

  Future<void> _generate() async {
    setState(() { _loading = true; _error = null; _content = null; });
    try {
      final data = await ApiClient.getExamRevisionNotes(
        courseCode:  widget.course.courseCode,
        courseTitle: widget.course.courseTitle,
      );
      setState(() { _content = data['content'] as String; _loading = false; });
    } catch (_) {
      setState(() {
        _error = 'Could not generate revision notes. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Revision'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        actions: [
          if (_content != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Regenerate',
              onPressed: _generate,
            ),
        ],
      ),
      body: _loading
          ? _LoadingView(
              message: 'Generating your revision sheet…',
              color: _accent)
          : _error != null
              ? _ErrorScreen(error: _error!, onRetry: _generate)
              : _ResultView(
                  title: '${widget.course.courseCode} Revision Sheet',
                  content: _content!,
                  accentColor: _accent,
                  onRegenerate: _generate,
                ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Exam Focus Areas Screen
// ══════════════════════════════════════════════════════════════════════════════

class _FocusAreasScreen extends StatefulWidget {
  final ExamCourse course;
  const _FocusAreasScreen({required this.course});

  @override
  State<_FocusAreasScreen> createState() => _FocusAreasScreenState();
}

class _FocusAreasScreenState extends State<_FocusAreasScreen> {
  bool           _loading = false;
  FocusAreasData? _data;
  String?        _error;

  static const _accent = Color(0xFFEF4444);

  @override
  void initState() { super.initState(); _generate(); }

  Future<void> _generate() async {
    setState(() { _loading = true; _error = null; _data = null; });
    try {
      final res = await ApiClient.getExamFocusAreas(
        courseCode:  widget.course.courseCode,
        courseTitle: widget.course.courseTitle,
      );
      final parsed = jsonDecode(res['focus_json'] as String) as Map<String, dynamic>;
      setState(() { _data = FocusAreasData.fromJson(parsed); _loading = false; });
    } catch (_) {
      setState(() {
        _error = 'Could not generate focus areas. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Focus Areas'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        actions: [
          if (_data != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _generate,
            ),
        ],
      ),
      body: _loading
          ? _LoadingView(
              message: 'Identifying key exam topics…', color: _accent)
          : _error != null
              ? _ErrorScreen(error: _error!, onRetry: _generate)
              : _buildContent(isDark),
    );
  }

  Widget _buildContent(bool isDark) {
    final data   = _data!;
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Study advice card
          if (data.studyAdvice.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accent.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(data.studyAdvice,
                        style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black54,
                            height: 1.5)),
                  ),
                ],
              ),
            ),

          Text('${data.focusAreas.length} Focus Areas — prioritised',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45)),
          const SizedBox(height: 10),

          ...data.focusAreas.map((f) => _FocusAreaCard(area: f, isDark: isDark)),
        ],
      ),
    );
  }
}

class _FocusAreaCard extends StatelessWidget {
  final FocusArea area;
  final bool      isDark;
  const _FocusAreaCard({required this.area, required this.isDark});

  Color get _weightColor {
    switch (area.estimatedWeight.toLowerCase()) {
      case 'high':   return _kRed;
      case 'low':    return _kGreen;
      default:       return _kAmber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _weightColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Rank badge
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                  color: _weightColor, shape: BoxShape.circle),
              child: Center(
                child: Text('${area.rank}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(area.topic,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _weightColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(area.estimatedWeight,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _weightColor)),
            ),
          ]),
          if (area.why.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(area.why,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54)),
          ],
          if (area.subtopics.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: area.subtopics.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.07)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(s,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.black54)),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared utility widgets
// ══════════════════════════════════════════════════════════════════════════════

/// Full-screen markdown result view (used by Practice Q and Revision Notes)
class _ResultView extends StatelessWidget {
  final String      title;
  final String      content;
  final Color       accentColor;
  final VoidCallback onRegenerate;
  const _ResultView({
    required this.title,
    required this.content,
    required this.accentColor,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Markdown(
            data: content,
            padding: const EdgeInsets.all(16),
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              h1: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: accentColor),
              h2: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
              strong: const TextStyle(fontWeight: FontWeight.w700),
              p:    Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRegenerate,
              style: OutlinedButton.styleFrom(
                foregroundColor: accentColor,
                side: BorderSide(color: accentColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Regenerate',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseBadge extends StatelessWidget {
  final ExamCourse course;
  final Color      color;
  const _CourseBadge({required this.course, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('📚', style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(course.courseTitle,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(course.courseCode,
              style: TextStyle(fontSize: 11, color: color,
                  fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  final String     label;
  final Color      color;
  final bool       loading;
  final VoidCallback onTap;
  const _GenerateButton({
    required this.label,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton.icon(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withOpacity(0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: loading
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.auto_awesome_rounded, size: 18),
      label: Text(loading ? 'Generating…' : label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
    ),
  );
}

class _LoadingView extends StatelessWidget {
  final String message;
  final Color  color;
  const _LoadingView({required this.message, required this.color});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: color),
      const SizedBox(height: 16),
      Text(message, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
    ]),
  );
}

class _ErrorBox extends StatelessWidget {
  final String text;
  const _ErrorBox(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _kRed.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline, color: _kRed, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: const TextStyle(color: _kRed, fontSize: 12))),
    ]),
  );
}

class _ErrorScreen extends StatelessWidget {
  final String       error;
  final VoidCallback onRetry;
  const _ErrorScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48, color: _kRed),
        const SizedBox(height: 16),
        Text(error, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ]),
    ),
  );
}


// ══════════════════════════════════════════════════════════════════════════════
// Phase 3 — Exam Readiness Tracker Card
// ══════════════════════════════════════════════════════════════════════════════

class _ExamReadinessCard extends StatefulWidget {
  final ExamCourse course;
  const _ExamReadinessCard({required this.course});

  @override
  State<_ExamReadinessCard> createState() => _ExamReadinessCardState();
}

class _ExamReadinessCardState extends State<_ExamReadinessCard> {
  ReadinessData? _data;
  bool           _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.getExamReadiness(
        courseCode:  widget.course.courseCode,
        courseTitle: widget.course.courseTitle,
      );
      if (mounted) {
        setState(() {
          _data    = ReadinessData.fromJson(res);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final scheme  = Theme.of(context).colorScheme;

    if (_loading) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kAmber.withOpacity(0.15)),
        ),
        child: const Center(
          child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    final data = _data;
    if (data == null) return const SizedBox.shrink();

    final pct   = data.readinessPercent;
    final color = pct >= 70 ? _kGreen : pct >= 40 ? _kAmber : _kRed;

    final activities = [
      _ActivityItem(
        icon:  '📄',
        label: 'Materials Read',
        done:  data.materialsRead > 0,
        value: data.materialsRead > 0 ? '${data.materialsRead}x' : null,
      ),
      _ActivityItem(
        icon:  '📝',
        label: 'Practice Done',
        done:  data.practiceSessions > 0,
        value: data.practiceSessions > 0 ? '${data.practiceSessions}x' : null,
      ),
      _ActivityItem(
        icon:  '⏱',
        label: 'Quiz Taken',
        done:  data.quizSessions > 0,
        value: data.avgQuizScore != null
            ? '${data.avgQuizScore!.round()}%'
            : null,
      ),
      _ActivityItem(
        icon:  '📖',
        label: 'Revised',
        done:  data.revisionSessions > 0,
        value: data.revisionSessions > 0 ? '${data.revisionSessions}x' : null,
      ),
      _ActivityItem(
        icon:  '🎯',
        label: 'Focus Viewed',
        done:  data.focusAreasViewed,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(children: [
            Text('📊 Exam Readiness',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: scheme.onSurface)),
            const Spacer(),
            Text('${pct.round()}%',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: color)),
          ]),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: (isDark ? Colors.white : Colors.black)
                  .withOpacity(0.1),
              color: color,
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 12),

          // Activity checklist
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: activities.map((a) => _ActivityChip(item: a)).toList(),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem {
  final String  icon;
  final String  label;
  final bool    done;
  final String? value;
  const _ActivityItem({
    required this.icon,
    required this.label,
    required this.done,
    this.value,
  });
}

class _ActivityChip extends StatelessWidget {
  final _ActivityItem item;
  const _ActivityChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color  = item.done ? _kGreen : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(item.icon, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 4),
        Text(
          item.value != null
              ? '${item.label} · ${item.value}'
              : item.label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color),
        ),
        const SizedBox(width: 3),
        Icon(
          item.done ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 11,
          color: color,
        ),
      ]),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// Phase 3 — Exam Countdown Card
// ══════════════════════════════════════════════════════════════════════════════

class _ExamCountdownCard extends StatefulWidget {
  final ExamCourse course;
  const _ExamCountdownCard({required this.course});

  @override
  State<_ExamCountdownCard> createState() => _ExamCountdownCardState();
}

class _ExamCountdownCardState extends State<_ExamCountdownCard> {
  ReadinessData?  _readiness;
  DailyTopicsData? _topics;
  bool            _loading        = true;
  bool            _showTopics     = false;
  bool            _settingDate    = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.getExamReadiness(
        courseCode:  widget.course.courseCode,
        courseTitle: widget.course.courseTitle,
      );
      final data = ReadinessData.fromJson(res);
      if (mounted) setState(() { _readiness = data; _loading = false; });

      // If exam date is set, also load today's recommended topics
      if (data.examDate != null && mounted) {
        _loadTopics();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTopics() async {
    try {
      final res = await ApiClient.getDailyExamTopics(
        courseCode:  widget.course.courseCode,
        courseTitle: widget.course.courseTitle,
      );
      final raw    = res['topics_json'] as String? ?? '{}';
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      if (mounted) {
        setState(() => _topics = DailyTopicsData.fromJson(parsed));
      }
    } catch (_) {}
  }

  Future<void> _pickExamDate(BuildContext context) async {
    final now  = DateTime.now();
    final initial = _readiness?.examDate ?? now.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context:      context,
      initialDate:  initial.isBefore(now) ? now : initial,
      firstDate:    now,
      lastDate:     now.add(const Duration(days: 365)),
      helpText:     'Select your exam date',
    );
    if (picked == null || !mounted) return;

    setState(() => _settingDate = true);
    try {
      final res = await ApiClient.setExamDate(
        courseCode:  widget.course.courseCode,
        courseTitle: widget.course.courseTitle,
        examDate:    picked,
      );
      final data = ReadinessData.fromJson(res);
      if (mounted) {
        setState(() {
          _readiness  = data;
          _settingDate = false;
          _topics     = null;
        });
        _loadTopics();
      }
    } catch (_) {
      if (mounted) setState(() => _settingDate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    if (_loading) return const SizedBox.shrink();

    final data = _readiness;

    // No exam date set yet → invite the student to set one
    if (data == null || data.examDate == null) {
      return GestureDetector(
        onTap: () => _pickExamDate(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.08)),
          ),
          child: Row(children: [
            const Text('📅', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set Your Exam Date',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: scheme.onSurface)),
                  Text('Get a personalised daily study plan',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black45)),
                ],
              ),
            ),
            if (_settingDate)
              const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey[400], size: 20),
          ]),
        ),
      );
    }

    // Exam date set → show countdown + optional daily topics
    final days   = data.daysUntilExam ?? 0;
    final urgency = data.urgencyLabel;
    final color  = days <= 1
        ? _kRed
        : days <= 3
            ? Colors.orange
            : days <= 7 ? _kAmber : _kGreen;
    final dateFmt = DateFormat('EEE, d MMM yyyy');

    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          // Countdown header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // Days badge
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$days',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: color)),
                    Text(days == 1 ? 'day' : 'days',
                        style: TextStyle(fontSize: 9, color: color)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Until Your Exam',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: scheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(dateFmt.format(data.examDate!),
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black45)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        urgency.isEmpty ? '' : '$urgency Priority',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color),
                      ),
                    ),
                  ],
                ),
              ),
              // Change date button
              GestureDetector(
                onTap: () => _pickExamDate(context),
                child: Icon(Icons.edit_calendar_rounded,
                    size: 18, color: Colors.grey[400]),
              ),
            ]),
          ),

          // Daily topics (expandable)
          if (_topics != null) ...[
            const Divider(height: 1),
            InkWell(
              onTap: () => setState(() => _showTopics = !_showTopics),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(children: [
                  const Text('📚', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Today's Topics (~${_topics!.estimatedStudyHours}h recommended)",
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    _showTopics
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey[400],
                    size: 18,
                  ),
                ]),
              ),
            ),
            if (_showTopics)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._topics!.todayTopics.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 20, height: 20,
                            margin: const EdgeInsets.only(top: 1, right: 8),
                            decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                shape: BoxShape.circle),
                            child: Center(
                              child: Text(
                                '${_topics!.todayTopics.indexOf(t) + 1}',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: color),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.topic,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)),
                                Text(
                                  '${t.estimatedMinutes} min · ${t.why}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black45),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                    if (_topics!.dailyTip.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('💡 ',
                                style: TextStyle(fontSize: 12)),
                            Expanded(
                              child: Text(_topics!.dailyTip,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
