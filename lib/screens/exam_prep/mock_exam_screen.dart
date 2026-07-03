// lib/screens/exam_prep/mock_exam_screen.dart
//
// AI Mock Exam System — Phase 1: CBT Engine.
//
// Flow: MockExamSetupScreen (course/source/count/difficulty/duration + Start,
// or Resume if an attempt is already in progress) -> MockExamScreen (timed
// CBT interface with question navigator, autosave, flag, submit) ->
// MockExamResultScreen (score only — no analytics/AI explanations in Phase 1).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../models/exam_prep_model.dart';
import '../../models/mock_exam_model.dart';
import '../../providers/ai_provider.dart';
import '../../widgets/premium_gate.dart';
import '../../utils/exam_lesson_launcher.dart';

const _kMockPrimary = Color(0xFF0EA5E9);   // sky blue — distinct from other exam tools
const _kMockDark    = Color(0xFF0369A1);
const _kGreen       = Color(0xFF22C55E);
const _kAmber       = Color(0xFFF59E0B);
const _kRed         = Color(0xFFEF4444);
const _kGrey        = Color(0xFF9CA3AF);

// ══════════════════════════════════════════════════════════════════════════════
// Setup screen
// ══════════════════════════════════════════════════════════════════════════════

class MockExamSetupScreen extends StatefulWidget {
  final ExamCourse course;
  const MockExamSetupScreen({super.key, required this.course});

  @override
  State<MockExamSetupScreen> createState() => _MockExamSetupScreenState();
}

class _MockExamSetupScreenState extends State<MockExamSetupScreen> {
  bool             _loadingConfig = true;
  MockExamConfig?  _config;
  String?          _loadError;

  int    _count      = 20;
  String _difficulty = 'medium';
  bool   _starting    = false;
  String? _startError;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() { _loadingConfig = true; _loadError = null; });
    try {
      final raw = await ApiClient.getMockExamConfig(
        courseCode:  widget.course.courseCode,
        courseTitle: widget.course.courseTitle,
      );
      final cfg = MockExamConfig.fromJson(raw);
      setState(() {
        _config        = cfg;
        _loadingConfig = false;
        if (cfg.questionCountOptions.isNotEmpty &&
            !cfg.questionCountOptions.contains(_count)) {
          _count = cfg.questionCountOptions.first;
        }
      });
    } catch (_) {
      setState(() {
        _loadError     = 'Could not load Mock Exam details. Please try again.';
        _loadingConfig = false;
      });
    }
  }

  Future<void> _resumeExam() async {
    final id = _config?.activeAttemptId;
    if (id == null) return;
    setState(() => _starting = true);
    try {
      final raw     = await ApiClient.getMockExamAttempt(id);
      final attempt = MockExamAttempt.fromJson(raw);
      if (!mounted) return;
      if (attempt.status != 'in_progress' || attempt.secondsRemaining <= 0) {
        // Timed out while away — show the result instead.
        await _goToResultFromAttempt(attempt.attemptId);
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MockExamScreen(
            course: widget.course, attempt: attempt)),
      );
    } catch (_) {
      setState(() {
        _starting   = false;
        _startError = 'Could not resume your exam. Please try again.';
      });
    }
  }

  Future<void> _goToResultFromAttempt(int attemptId) async {
    try {
      final raw    = await ApiClient.getMockExamReview(attemptId);
      final review = MockExamReview.fromJson(raw);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MockExamResultScreen(
            course: widget.course, review: review)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _starting   = false;
        _startError = 'Could not load your exam result. Please try again.';
      });
    }
  }

  Future<void> _startExam() async {
    setState(() { _starting = true; _startError = null; });
    try {
      final raw     = await ApiClient.startMockExam(
        courseCode:    widget.course.courseCode,
        courseTitle:   widget.course.courseTitle,
        questionCount: _count,
        difficulty:    _difficulty,
      );
      final attempt = MockExamAttempt.fromJson(raw);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MockExamScreen(
            course: widget.course, attempt: attempt)),
      );
    } catch (e) {
      setState(() {
        _starting   = false;
        _startError = e is ApiException
            ? e.message
            : 'Could not generate your Mock Exam. Please try again.';
      });
    }
  }

  int get _estimatedMinutes =>
      _config?.estimatedMinutes[_count.toString()] ?? ((_count * 1.5).round());

  @override
  Widget build(BuildContext context) {
    final entitlements = context.watch<AiProvider>().entitlements;
    if (!entitlements.canUseExamAiTools) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mock Exam'),
            backgroundColor: _kMockDark, foregroundColor: Colors.white),
        body: const Center(child: PremiumGate(feature: PremiumFeature.examAiTools)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mock Exam'),
        backgroundColor: _kMockDark,
        foregroundColor: Colors.white,
      ),
      body: _loadingConfig
          ? const Center(child: CircularProgressIndicator(color: _kMockPrimary))
          : _loadError != null
              ? _ErrorState(message: _loadError!, onRetry: _loadConfig)
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final cfg    = _config!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!cfg.hasMaterial) {
      return _ErrorState(
        message:
            'No uploaded course material found for ${widget.course.courseTitle} yet.\n\n'
            'Mock Exam questions are generated only from your uploaded PDFs, notes '
            'and summaries — upload some materials to Exam Preparation first.',
        onRetry: _loadConfig,
        icon: Icons.folder_off_rounded,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course + source card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kMockPrimary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kMockPrimary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('📝', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.course.courseTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(widget.course.courseCode,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: _kMockPrimary)),
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.source_rounded, size: 14, color: _kMockPrimary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        'Source: Uploaded materials (${cfg.sourceCount} document'
                        '${cfg.sourceCount == 1 ? '' : 's'})',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54)),
                  ),
                ]),
              ],
            ),
          ),

          if (cfg.hasActiveAttempt) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kAmber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: const [
                    Icon(Icons.history_toggle_off_rounded, color: _kAmber, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('You have an unfinished Mock Exam',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _starting ? null : _resumeExam,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAmber,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _starting
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Resume Exam',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text('Starting a new exam will discard this one.',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38)),
            ),
          ],

          const SizedBox(height: 24),
          const Text('Number of questions',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          Row(
            children: cfg.questionCountOptions.map((n) {
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
                            ? _kMockPrimary
                            : (isDark ? Colors.white.withOpacity(0.07)
                                      : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: selected ? _kMockPrimary : Colors.transparent,
                            width: 2),
                      ),
                      child: Text('$n',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: selected ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          const Text('Difficulty',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          Row(
            children: cfg.difficultyOptions.map((d) {
              final selected = d == _difficulty;
              final label = d[0].toUpperCase() + d.substring(1);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _difficulty = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? _kMockPrimary
                            : (isDark ? Colors.white.withOpacity(0.07)
                                      : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: selected ? _kMockPrimary : Colors.transparent,
                            width: 2),
                      ),
                      child: Text(label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: selected ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kMockPrimary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kMockPrimary.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.timer_outlined, color: _kMockPrimary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    'Estimated duration: $_estimatedMinutes minutes\n'
                    'Timer starts as soon as you tap Start — the exam '
                    'auto-submits when time runs out.',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54)),
              ),
            ]),
          ),

          if (_startError != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(_startError!),
          ],

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _starting ? null : _startExam,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kMockPrimary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _kMockPrimary.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _starting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.play_circle_fill_rounded, size: 20),
              label: Text(_starting ? 'Preparing your exam…' : 'Start Mock Exam',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CBT Exam screen
// ══════════════════════════════════════════════════════════════════════════════

class MockExamScreen extends StatefulWidget {
  final ExamCourse       course;
  final MockExamAttempt  attempt;
  const MockExamScreen({super.key, required this.course, required this.attempt});

  @override
  State<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends State<MockExamScreen> {
  late int        _current;
  late Timer      _timer;
  late int        _secondsLeft;
  bool            _submitting = false;

  @override
  void initState() {
    super.initState();
    _current     = 0;
    _secondsLeft = widget.attempt.secondsRemaining;
    _markVisited(_currentQuestion.id);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 0) {
        _timer.cancel();
        _autoSubmit();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  MockExamAttempt get _attempt => widget.attempt;
  MockExamQuestion get _currentQuestion => _attempt.questions[_current];

  String get _timeLabel {
    final h = _secondsLeft ~/ 3600;
    final m = (_secondsLeft % 3600) ~/ 60;
    final s = _secondsLeft % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _markVisited(int questionId) {
    if (_attempt.visited.contains(questionId)) return;
    setState(() => _attempt.visited.add(questionId));
    ApiClient.saveMockExamAnswer(
      attemptId: _attempt.attemptId,
      questionId: questionId,
      answer: _currentQuestion.selectedAnswer,
      visited: true,
    ).catchError((_) => <String, dynamic>{});
  }

  void _select(dynamic value) {
    setState(() => _currentQuestion.selectedAnswer = value);
    // Autosave immediately — every selected answer is saved right away.
    ApiClient.saveMockExamAnswer(
      attemptId: _attempt.attemptId,
      questionId: _currentQuestion.id,
      answer: value,
      visited: true,
    ).catchError((_) => <String, dynamic>{});
  }

  void _toggleFlag() {
    final id = _currentQuestion.id;
    setState(() {
      if (_attempt.flagged.contains(id)) {
        _attempt.flagged.remove(id);
      } else {
        _attempt.flagged.add(id);
      }
    });
    ApiClient.toggleMockExamFlag(
      attemptId: _attempt.attemptId,
      questionId: id,
    ).catchError((_) => <String, dynamic>{});
  }

  void _goTo(int index) {
    if (index < 0 || index >= _attempt.questions.length) return;
    setState(() => _current = index);
    _markVisited(_currentQuestion.id);
  }

  void _next() {
    if (_current < _attempt.questions.length - 1) {
      _goTo(_current + 1);
    } else {
      _confirmSubmit();
    }
  }

  void _prev() => _goTo(_current - 1);

  Future<void> _autoSubmit() async {
    // Timer reached zero — submit immediately, no confirmation dialog.
    await _doSubmit();
  }

  Future<void> _confirmSubmit() async {
    final unanswered = _attempt.questionCount - _attempt.answeredCount;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Submit Mock Exam?'),
        content: Text(unanswered > 0
            ? 'You have $unanswered unanswered question${unanswered == 1 ? '' : 's'}. '
              'Once submitted, you cannot change your answers.'
            : 'Once submitted, you cannot change your answers.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Reviewing')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: _kMockPrimary,
                  foregroundColor: Colors.white),
              child: const Text('Submit')),
        ],
      ),
    );
    if (proceed == true) await _doSubmit();
  }

  Future<void> _doSubmit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    _timer.cancel();
    try {
      final raw    = await ApiClient.submitMockExam(_attempt.attemptId);
      final review = MockExamReview.fromJson(raw);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MockExamResultScreen(
            course: widget.course, review: review)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not submit. Check your connection and try again.')));
    }
  }

  void _openNavigator() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _QuestionNavigatorSheet(
        attempt: _attempt,
        current: _current,
        onSelect: (i) { Navigator.pop(context); _goTo(i); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final total  = _attempt.questionCount;
    final q      = _currentQuestion;
    final isRed  = _secondsLeft < 60;
    final flagged = _attempt.flagged.contains(q.id);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Leave Mock Exam?'),
            content: const Text(
                'Your progress is saved. You can resume this exam later from '
                'Exam Prep before time runs out.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('Stay')),
              TextButton(onPressed: () => Navigator.pop(context, true),
                  child: const Text('Leave')),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _kMockDark,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          title: Row(children: [
            Text('Question ${_current + 1} of $total',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
          ]),
          actions: [
            IconButton(
              tooltip: 'Question navigator',
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: _openNavigator,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: total > 0 ? (_current + 1) / total : 0,
              backgroundColor: Colors.white24,
              color: Colors.white,
              minHeight: 4,
            ),
          ),
        ),
        body: Stack(
          children: [
            Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _kMockPrimary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _kMockPrimary.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            _TypeChip(type: q.type),
                            const SizedBox(width: 6),
                            if (flagged)
                              const Icon(Icons.flag_rounded, size: 16, color: _kRed),
                          ]),
                          const SizedBox(height: 10),
                          Text(q.question,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600, height: 1.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Options
                    ...List.generate(q.options.length, (i) {
                      final selected = q.selectedAnswer == i;
                      final letter = q.type == 'true_false'
                          ? null
                          : String.fromCharCode(65 + i);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => _select(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: selected
                                  ? _kMockPrimary.withOpacity(0.12)
                                  : (isDark ? Colors.white.withOpacity(0.05)
                                            : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: selected ? _kMockPrimary
                                      : (isDark ? Colors.white12 : Colors.grey.shade200),
                                  width: selected ? 2 : 1),
                            ),
                            child: Row(children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: selected ? _kMockPrimary : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: selected ? _kMockPrimary : Colors.grey.shade400),
                                ),
                                child: Center(
                                  child: letter != null
                                      ? Text(letter,
                                          style: TextStyle(
                                              fontSize: 12, fontWeight: FontWeight.w700,
                                              color: selected ? Colors.white : Colors.grey))
                                      : Icon(
                                          selected ? Icons.check : null,
                                          size: 14,
                                          color: selected ? Colors.white : Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(q.options[i],
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: selected ? _kMockPrimary : scheme.onSurface)),
                              ),
                            ]),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Bottom bar: Previous / Flag / Next / Submit
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06),
                      blurRadius: 8, offset: const Offset(0, -2)),
                ],
              ),
              child: Row(children: [
                OutlinedButton(
                  onPressed: _current > 0 ? _prev : null,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: _kMockPrimary,
                      side: const BorderSide(color: _kMockPrimary),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Icon(Icons.chevron_left_rounded),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _toggleFlag,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: flagged ? _kRed : _kGrey,
                      side: BorderSide(color: flagged ? _kRed : _kGrey),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Icon(flagged ? Icons.flag_rounded : Icons.flag_outlined),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _next,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _kMockPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(
                        _current < total - 1 ? 'Next' : 'Submit Exam',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ],
        ),
            if (_submitting) const _GradingOverlay(),
          ],
        ),
      ),
    );
  }
}

class _GradingOverlay extends StatelessWidget {
  const _GradingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.55),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: _kMockPrimary),
            SizedBox(height: 16),
            Text('Grading your exam…',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            SizedBox(height: 6),
            Text('AI is reviewing your answers and preparing explanations.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String type;
  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      'true_false' => 'True / False',
      'fill_blank' => 'Fill in the Blank',
      _            => 'Multiple Choice',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kMockPrimary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: _kMockDark)),
    );
  }
}

// ── Question navigator ─────────────────────────────────────────────────────────

class _QuestionNavigatorSheet extends StatelessWidget {
  final MockExamAttempt        attempt;
  final int                    current;
  final ValueChanged<int>      onSelect;
  const _QuestionNavigatorSheet({
    required this.attempt, required this.current, required this.onSelect,
  });

  Color _colorFor(QuestionStatus s) => switch (s) {
    QuestionStatus.answered   => _kGreen,
    QuestionStatus.flagged    => _kRed,
    QuestionStatus.visited    => _kAmber,
    QuestionStatus.notVisited => Colors.white,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Question Navigator',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            Text('${attempt.answeredCount} of ${attempt.questionCount} answered',
                style: TextStyle(
                    fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: List.generate(attempt.questions.length, (i) {
                final q      = attempt.questions[i];
                final status = attempt.statusFor(q.id);
                final isCurrent = i == current;
                return GestureDetector(
                  onTap: () => onSelect(i),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: _colorFor(status),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isCurrent ? _kMockPrimary
                              : (status == QuestionStatus.notVisited
                                  ? Colors.grey.shade400 : Colors.transparent),
                          width: isCurrent ? 2.5 : 1),
                    ),
                    child: Center(
                      child: Text('${i + 1}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: status == QuestionStatus.notVisited
                                  ? Colors.black87 : Colors.white)),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            Wrap(spacing: 16, runSpacing: 8, children: const [
              _LegendDot(color: Colors.white, label: 'Not visited', border: true),
              _LegendDot(color: _kAmber, label: 'Visited'),
              _LegendDot(color: _kGreen, label: 'Answered'),
              _LegendDot(color: _kRed, label: 'Flagged'),
            ]),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color   color;
  final String  label;
  final bool    border;
  const _LegendDot({required this.color, required this.label, this.border = false});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 14, height: 14,
        decoration: BoxDecoration(
          color: color, shape: BoxShape.circle,
          border: border ? Border.all(color: Colors.grey.shade400) : null,
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Result screen (Phase 1: score only — no analytics/AI explanations)
// ══════════════════════════════════════════════════════════════════════════════

class MockExamResultScreen extends StatefulWidget {
  final ExamCourse    course;
  final MockExamReview review;
  const MockExamResultScreen({super.key, required this.course, required this.review});

  @override
  State<MockExamResultScreen> createState() => _MockExamResultScreenState();
}

class _MockExamResultScreenState extends State<MockExamResultScreen> {
  late MockExamReview _review = widget.review;
  bool _regenerating = false;

  Color _gradeColor(String grade) => switch (grade) {
    'A' => _kGreen,
    'B' => _kGreen,
    'C' => _kAmber,
    'D' => _kAmber,
    _   => _kRed,
  };

  Future<void> _retryExplanations() async {
    setState(() => _regenerating = true);
    try {
      await ApiClient.regenerateMockExamExplanations(_review.attemptId);
      final raw = await ApiClient.getMockExamReview(_review.attemptId);
      if (!mounted) return;
      setState(() { _review = MockExamReview.fromJson(raw); _regenerating = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _regenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Still unavailable. Please try again shortly.')));
    }
  }

  void _learnTopic(String topic) {
    launchExamLesson(
      context,
      topic: topic,
      courseCode: widget.course.courseCode,
      courseTitle: widget.course.courseTitle,
      isReview: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final review = _review;
    final pct    = review.scorePercent;
    final color  = _gradeColor(review.grade);
    final emoji  = pct >= 70 ? '🎉' : pct >= 50 ? '😊' : '💪';
    final msg    = pct >= 70
        ? 'Excellent! You\'re well prepared for the real exam.'
        : pct >= 50
            ? 'Good effort! Review your weak topics below.'
            : 'Keep studying — take this exam again once you\'ve reviewed the material.';

    final weakOnes = review.weakTopics.where((t) => t.isWeak).toList();
    final wrongQuestions = review.questions
        .where((q) => q.status != 'correct')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mock Exam Result'),
        backgroundColor: _kMockDark,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (review.autoSubmitted) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _kAmber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  Icon(Icons.timer_off_rounded, color: _kAmber, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Time ran out — your exam was submitted automatically.',
                        style: TextStyle(fontSize: 12, color: _kAmber,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ],

            // Score + grade
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 128, height: 128,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 28)),
                      Text('${pct.round()}%',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                    ],
                  ),
                ),
                Positioned(
                  bottom: -2, right: -2,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                    ),
                    child: Center(
                      child: Text(review.grade,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('${review.correctCount} / ${review.total} correct',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(msg, textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),

            const SizedBox(height: 20),

            // Time stats
            Row(children: [
              Expanded(child: _StatTile(
                  icon: Icons.timer_outlined, label: 'Time Used', value: review.timeUsedLabel)),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(
                  icon: Icons.speed_rounded, label: 'Avg / Question', value: review.avgTimeLabel)),
            ]),
            const SizedBox(height: 10),

            // Correct / Wrong / Partial / Skipped chips
            Wrap(spacing: 8, runSpacing: 8, children: [
              _CountChip(label: 'Correct', count: review.correctCount, color: _kGreen),
              _CountChip(label: 'Wrong', count: review.wrongCount, color: _kRed),
              if (review.partiallyCorrectCount > 0)
                _CountChip(label: 'Partial', count: review.partiallyCorrectCount, color: _kAmber),
              _CountChip(label: 'Skipped', count: review.skippedCount, color: _kGrey),
            ]),

            if (!review.explanationsReady) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kAmber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.auto_awesome_rounded, color: _kAmber, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Some AI explanations aren\'t ready yet.',
                        style: TextStyle(fontSize: 12, color: _kAmber, fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: _regenerating ? null : _retryExplanations,
                    child: _regenerating
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _kAmber))
                        : const Text('Retry', style: TextStyle(color: _kAmber, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 28),

            // Weak topics
            if (review.weakTopics.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Performance by Topic',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface)),
              ),
              const SizedBox(height: 10),
              ...review.weakTopics.map((t) {
                final frac = t.total > 0 ? t.correct / t.total : 0.0;
                final barColor = frac >= 0.7 ? _kGreen : frac >= 0.5 ? _kAmber : _kRed;
                final correctLabel = t.correct == t.correct.roundToDouble()
                    ? t.correct.round().toString() : t.correct.toStringAsFixed(1);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(t.topic,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        Text('$correctLabel/${t.total}',
                            style: TextStyle(fontSize: 12, color: barColor,
                                fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 8,
                          backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                          color: barColor,
                        ),
                      ),
                      if (t.isWeak) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 34,
                          child: OutlinedButton.icon(
                            onPressed: () => _learnTopic(t.topic),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: _kMockPrimary,
                                side: const BorderSide(color: _kMockPrimary),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            icon: const Icon(Icons.school_rounded, size: 16),
                            label: const Text('Learn this Topic',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              if (weakOnes.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('No weak topics detected — nice work!',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
                ),
            ],

            // Question-by-question review
            if (wrongQuestions.isNotEmpty) ...[
              const SizedBox(height: 28),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Review Your Answers',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface)),
              ),
              const SizedBox(height: 10),
              ...wrongQuestions.map((q) => _QuestionReviewCard(
                    question: q,
                    courseCode: widget.course.courseCode,
                    courseTitle: widget.course.courseTitle,
                  )),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    foregroundColor: _kMockPrimary,
                    side: const BorderSide(color: _kMockPrimary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Back to Exam Prep',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  const _StatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(children: [
        Icon(icon, size: 18, color: _kMockPrimary),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45)),
      ]),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int    count;
  final Color  color;
  const _CountChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text('$count $label',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _QuestionReviewCard extends StatefulWidget {
  final GradedQuestion question;
  final String         courseCode;
  final String         courseTitle;
  const _QuestionReviewCard({
    required this.question, required this.courseCode, required this.courseTitle,
  });

  @override
  State<_QuestionReviewCard> createState() => _QuestionReviewCardState();
}

class _QuestionReviewCardState extends State<_QuestionReviewCard> {
  bool _expanded = false;

  ({Color color, String label, IconData icon}) get _statusStyle => switch (widget.question.status) {
    'wrong'             => (color: _kRed, label: 'Wrong', icon: Icons.close_rounded),
    'partially_correct' => (color: _kAmber, label: 'Partially Correct', icon: Icons.remove_circle_outline_rounded),
    'skipped'           => (color: _kGrey, label: 'Skipped', icon: Icons.remove_rounded),
    _                   => (color: _kGreen, label: 'Correct', icon: Icons.check_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q      = widget.question;
    final s      = _statusStyle;
    final exp    = q.explanation;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: s.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(s.icon, size: 12, color: s.color),
                    const SizedBox(width: 4),
                    Text(s.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: s.color)),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(q.question,
                      maxLines: _expanded ? null : 2,
                      overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: _kGrey, size: 20),
              ]),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  if (exp != null) ...[
                    _ReviewLine(label: 'Correct answer', text: exp.correctAnswer, color: _kGreen),
                    const SizedBox(height: 8),
                    _ReviewLine(label: 'Explanation', text: exp.simpleExplanation),
                    const SizedBox(height: 8),
                    if (q.status == 'wrong') ...[
                      _ReviewLine(label: 'Why your answer was incorrect', text: exp.whyIncorrect),
                      const SizedBox(height: 8),
                    ],
                    _ReviewLine(label: 'Key concept', text: exp.keyConcept, color: _kMockPrimary),
                  ] else ...[
                    Text(
                        q.status == 'skipped'
                            ? 'You didn\'t answer this one.'
                            : 'Explanation not available yet.',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      onPressed: () => launchExamLesson(
                        context,
                        topic: q.topic,
                        courseCode: widget.courseCode,
                        courseTitle: widget.courseTitle,
                        isReview: true,
                      ),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: _kMockPrimary,
                          side: const BorderSide(color: _kMockPrimary),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      icon: const Icon(Icons.school_rounded, size: 14),
                      label: Text('Learn "${q.topic}"',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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

class _ReviewLine extends StatelessWidget {
  final String label;
  final String text;
  final Color? color;
  const _ReviewLine({required this.label, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                color: color ?? _kGrey, letterSpacing: 0.4)),
        const SizedBox(height: 3),
        Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
      ],
    );
  }
}

// ── Shared small widgets ─────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  final IconData      icon;
  const _ErrorState({
    required this.message, required this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 52, color: _kGrey),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
              backgroundColor: _kMockPrimary, foregroundColor: Colors.white),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ]),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String text;
  const _ErrorBanner(this.text);

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
      Expanded(child: Text(text, style: const TextStyle(color: _kRed, fontSize: 12))),
    ]),
  );
}
