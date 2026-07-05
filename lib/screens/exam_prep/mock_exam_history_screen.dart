// lib/screens/exam_prep/mock_exam_history_screen.dart
//
// AI Mock Exam System — Phase 3: connects mock exam performance to the
// student's overall learning progress. Shows history, aggregate statistics,
// a score-progression graph, and topics ranked weakest-to-strongest across
// every mock exam taken for a course.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/exam_prep_model.dart';
import '../../models/mock_exam_model.dart';
import '../../utils/exam_lesson_launcher.dart';

const _kMockPrimary = Color(0xFF0EA5E9);
const _kMockDark    = Color(0xFF0369A1);
const _kGreen       = Color(0xFF22C55E);
const _kAmber       = Color(0xFFF59E0B);
const _kRed         = Color(0xFFEF4444);
const _kGrey        = Color(0xFF9CA3AF);

class MockExamHistoryScreen extends StatefulWidget {
  final ExamCourse course;
  const MockExamHistoryScreen({super.key, required this.course});

  @override
  State<MockExamHistoryScreen> createState() => _MockExamHistoryScreenState();
}

class _MockExamHistoryScreenState extends State<MockExamHistoryScreen> {
  bool _loading = true;
  String? _error;
  MockExamStatistics? _stats;
  List<MockExamHistoryItem> _history = [];
  List<WeakTopic> _weakTopics = [];
  MockExamConfig? _config;
  ReadinessPrediction? _prediction;
  MockExamAnalytics? _analytics;
  List<Achievement> _achievements = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait<dynamic>([
        ApiClient.getMockExamStatistics(courseCode: widget.course.courseCode),
        ApiClient.getAllMockExamHistory(courseCode: widget.course.courseCode),
        ApiClient.getMockExamWeakTopics(widget.course.courseCode),
        ApiClient.getMockExamConfig(
            courseCode: widget.course.courseCode, courseTitle: widget.course.courseTitle),
        ApiClient.getMockExamAchievements(),
      ]);
      final stats   = MockExamStatistics.fromJson(results[0] as Map<String, dynamic>);
      final history = (results[1] as List)
          .map((e) => MockExamHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final weak    = (results[2] as List)
          .map((e) => WeakTopic.fromJson(e as Map<String, dynamic>))
          .toList();
      final config  = MockExamConfig.fromJson(results[3] as Map<String, dynamic>);
      final achievements = (results[4] as List)
          .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
          .toList();

      ReadinessPrediction? prediction;
      MockExamAnalytics? analytics;
      if (config.readinessPrediction || config.advancedAnalytics) {
        final premiumResults = await Future.wait([
          if (config.readinessPrediction)
            ApiClient.getMockExamReadinessPrediction(
                courseCode: widget.course.courseCode, courseTitle: widget.course.courseTitle)
          else
            Future.value(<String, dynamic>{}),
          if (config.advancedAnalytics)
            ApiClient.getMockExamAnalytics(widget.course.courseCode)
          else
            Future.value(<String, dynamic>{}),
        ]);
        if (config.readinessPrediction && premiumResults[0].isNotEmpty) {
          prediction = ReadinessPrediction.fromJson(premiumResults[0]);
        }
        if (config.advancedAnalytics && premiumResults[1].isNotEmpty) {
          analytics = MockExamAnalytics.fromJson(premiumResults[1]);
        }
      }

      if (!mounted) return;
      setState(() {
        _stats        = stats;
        _history      = history;
        _weakTopics   = weak;
        _config       = config;
        _prediction   = prediction;
        _analytics    = analytics;
        _achievements = achievements;
        _loading      = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error   = 'Could not load your mock exam history. Please try again.';
        _loading = false;
      });
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

  void _showPremiumSheet(String feature) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👑', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text('$feature is a Premium feature',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
                'Upgrade to unlock AI Readiness Prediction, Advanced Analytics, '
                'and unlimited mock exam history.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _kMockPrimary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mock Exam History'),
        backgroundColor: _kMockDark,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kMockPrimary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: _kGrey),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _kMockPrimary, foregroundColor: Colors.white),
                          child: const Text('Retry')),
                    ]),
                  ),
                )
              : (_stats?.totalExams ?? 0) == 0
                  ? _EmptyState(courseTitle: widget.course.courseTitle)
                  : _buildDashboard(context),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final stats = _stats!;
    return RefreshIndicator(
      onRefresh: _load,
      color: _kMockPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.course.courseTitle,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),

            // Statistics grid
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [
                _StatCard(icon: Icons.emoji_events_rounded, label: 'Highest',
                    value: stats.highestScore != null ? '${stats.highestScore!.round()}%' : '—',
                    color: _kGreen),
                _StatCard(icon: Icons.trending_down_rounded, label: 'Lowest',
                    value: stats.lowestScore != null ? '${stats.lowestScore!.round()}%' : '—',
                    color: _kRed),
                _StatCard(icon: Icons.equalizer_rounded, label: 'Average',
                    value: stats.averageScore != null ? '${stats.averageScore!.round()}%' : '—',
                    color: _kMockPrimary),
                _StatCard(icon: Icons.fact_check_rounded, label: 'Total Exams',
                    value: '${stats.totalExams}', color: _kAmber),
                _StatCard(icon: Icons.schedule_rounded, label: 'Study Time',
                    value: stats.totalStudyTimeLabel, color: _kMockPrimary),
                _StatCard(icon: Icons.speed_rounded, label: 'Avg Completion',
                    value: stats.averageCompletionTimeLabel, color: _kAmber),
              ],
            ),

            if (_achievements.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text('Achievements', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 12),
              _AchievementsRow(achievements: _achievements),
            ],

            const SizedBox(height: 28),
            const Text('Score Progression',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            _ScoreProgressionChart(
              // History comes back most-recent-first; chart reads left->right chronologically.
              scores: _history.reversed.map((h) => h.scorePercent ?? 0).toList(),
            ),

            const SizedBox(height: 28),
            Row(children: [
              const Text('AI Readiness Prediction',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              if (_config?.readinessPrediction != true)
                _PremiumBadge(onTap: () => _showPremiumSheet('AI Readiness Prediction')),
            ]),
            const SizedBox(height: 12),
            _prediction != null
                ? _ReadinessPredictionCard(prediction: _prediction!)
                : _LockedCard(
                    message: 'Upgrade to Premium to see your predicted exam score range.',
                    onTap: () => _showPremiumSheet('AI Readiness Prediction'),
                  ),

            const SizedBox(height: 28),
            Row(children: [
              const Text('Advanced Analytics',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              if (_config?.advancedAnalytics != true)
                _PremiumBadge(onTap: () => _showPremiumSheet('Advanced Analytics')),
            ]),
            const SizedBox(height: 12),
            _analytics != null && _analytics!.totalExamsAnalyzed > 0
                ? _AdvancedAnalyticsSection(analytics: _analytics!)
                : _LockedCard(
                    message: _config?.advancedAnalytics == true
                        ? 'Take a few mock exams to unlock topic mastery, difficulty trends, and heatmaps.'
                        : 'Upgrade to Premium for topic mastery, difficulty trends, and heatmaps.',
                    onTap: _config?.advancedAnalytics == true
                        ? null : () => _showPremiumSheet('Advanced Analytics'),
                  ),

            if (_weakTopics.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text('Weak Topics (across all mock exams)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Text('Ranked weakest to strongest',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 12),
              ..._weakTopics.map((t) => _WeakTopicRow(topic: t, onLearn: () => _learnTopic(t.topic))),
            ],

            const SizedBox(height: 28),
            Row(children: [
              const Text('History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              if (stats.historyCapped)
                _PremiumBadge(onTap: () => _showPremiumSheet('Unlimited History')),
            ]),
            const SizedBox(height: 12),
            if (stats.historyCapped) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                    'Showing your last ${stats.historyLimit} results. Upgrade for unlimited history.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ),
            ],
            ..._history.map((h) => _HistoryRow(item: h)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String courseTitle;
  const _EmptyState({required this.courseTitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🖥️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text('No mock exams yet for $courseTitle',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          Text('Take your first mock exam to start tracking your progress here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  final VoidCallback onTap;
  const _PremiumBadge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('👑', style: TextStyle(fontSize: 10)),
          SizedBox(width: 3),
          Text('Premium', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
        ]),
      ),
    );
  }
}

class _LockedCard extends StatelessWidget {
  final String message;
  final VoidCallback? onTap;
  const _LockedCard({required this.message, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
              style: BorderStyle.solid),
        ),
        child: Row(children: [
          Icon(onTap != null ? Icons.lock_outline_rounded : Icons.hourglass_empty_rounded,
              color: onTap != null ? Colors.amber : _kGrey, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
          ),
        ]),
      ),
    );
  }
}

class _ReadinessPredictionCard extends StatelessWidget {
  final ReadinessPrediction prediction;
  const _ReadinessPredictionCard({required this.prediction});

  Color get _confColor => switch (prediction.confidence) {
    'High' => _kGreen,
    'Medium' => _kAmber,
    _ => _kRed,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kMockPrimary.withOpacity(0.12), _kMockPrimary.withOpacity(0.03)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kMockPrimary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Expected Score', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _confColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${prediction.confidence} Confidence',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _confColor)),
            ),
          ]),
          const SizedBox(height: 8),
          Text('${prediction.expectedScoreLow}–${prediction.expectedScoreHigh}%',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _kMockDark)),
          const SizedBox(height: 14),
          Wrap(spacing: 16, runSpacing: 8, children: [
            _PredictionFactor(label: 'Study Progress',
                value: '${prediction.studyProgressPercent.round()}%'),
            _PredictionFactor(label: 'Mock Exams', value: '${prediction.mockExamsTaken}'),
            _PredictionFactor(label: 'Topics Completed', value: '${prediction.dailyTopicsCompleted}'),
            _PredictionFactor(label: 'Weak Areas', value: '${prediction.weakAreasCount}'),
          ]),
          const SizedBox(height: 4),
          Text('Based on your study progress, mock exam history, daily topics, and weak areas.',
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
        ],
      ),
    );
  }
}

class _PredictionFactor extends StatelessWidget {
  final String label;
  final String value;
  const _PredictionFactor({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kMockDark)),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
    ]);
  }
}

class _AdvancedAnalyticsSection extends StatelessWidget {
  final MockExamAnalytics analytics;
  const _AdvancedAnalyticsSection({required this.analytics});

  Color _colorFor(double pct) => pct >= 70 ? _kGreen : pct >= 50 ? _kAmber : _kRed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Topic mastery
        Text('Topic Mastery', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black54)),
        const SizedBox(height: 8),
        ...analytics.topicMastery.take(8).map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(
                  width: 100,
                  child: Text(t.topic, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: t.masteryPercent / 100, minHeight: 8,
                      backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                      color: _colorFor(t.masteryPercent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text('${t.masteryPercent.round()}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: _colorFor(t.masteryPercent))),
                ),
              ]),
            )),

        if (analytics.difficultyTrend.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Difficulty Trend', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black54)),
          const SizedBox(height: 10),
          Row(
            children: analytics.difficultyTrend.map((d) {
              final color = _colorFor(d.avgPercent);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(children: [
                    Text('${d.avgPercent.round()}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                    const SizedBox(height: 6),
                    Container(
                      height: 60, width: double.infinity,
                      alignment: Alignment.bottomCenter,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: FractionallySizedBox(
                        heightFactor: (d.avgPercent / 100).clamp(0.03, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(d.difficulty[0].toUpperCase() + d.difficulty.substring(1),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],

        if (analytics.heatmap.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Topic × Difficulty Heatmap', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black54)),
          const SizedBox(height: 10),
          _HeatmapGrid(cells: analytics.heatmap),
        ],
      ],
    );
  }
}

class _HeatmapGrid extends StatelessWidget {
  final List<HeatmapCell> cells;
  const _HeatmapGrid({required this.cells});

  Color _colorFor(double pct) {
    if (pct >= 70) return _kGreen;
    if (pct >= 50) return _kAmber;
    return _kRed;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topics = cells.map((c) => c.topic).toSet().toList();
    const diffs = ['easy', 'medium', 'hard'];

    HeatmapCell? cellFor(String topic, String diff) {
      for (final c in cells) {
        if (c.topic == topic && c.difficulty == diff) return c;
      }
      return null;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(56),
        columnWidths: const {0: FixedColumnWidth(110)},
        children: [
          TableRow(children: [
            const SizedBox(),
            ...diffs.map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(d[0].toUpperCase() + d.substring(1),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                )),
          ]),
          ...topics.map((topic) => TableRow(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Text(topic, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                ...diffs.map((d) {
                  final cell = cellFor(topic, d);
                  if (cell == null) {
                    return Padding(
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    );
                  }
                  final color = _colorFor(cell.percent);
                  return Padding(
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.18 + (cell.percent / 100) * 0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withOpacity(0.4)),
                      ),
                      child: Text('${cell.percent.round()}',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                    ),
                  );
                }),
              ])),
        ],
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  final VoidCallback onTap;
  const _PremiumBadge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('👑', style: TextStyle(fontSize: 10)),
          SizedBox(width: 3),
          Text('Premium', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
        ]),
      ),
    );
  }
}

class _LockedCard extends StatelessWidget {
  final String message;
  final VoidCallback? onTap;
  const _LockedCard({required this.message, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
              style: BorderStyle.solid),
        ),
        child: Column(children: [
          Icon(onTap != null ? Icons.lock_outline_rounded : Icons.hourglass_empty_rounded,
              size: 28, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }
}

class _ReadinessPredictionCard extends StatelessWidget {
  final ReadinessPrediction prediction;
  const _ReadinessPredictionCard({required this.prediction});

  Color get _confidenceColor => switch (prediction.confidence) {
    'High' => _kGreen,
    'Medium' => _kAmber,
    _ => _kRed,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
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
            const Text('Expected Score',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kMockPrimary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _confidenceColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${prediction.confidence} Confidence',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _confidenceColor)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('${prediction.expectedScoreLow}–${prediction.expectedScoreHigh}%',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _kMockDark)),
          const SizedBox(height: 14),
          const Text('Based on', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kGrey)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _BasedOnChip(label: 'Study Progress', value: '${prediction.studyProgressPercent.round()}%'),
            _BasedOnChip(label: 'Mock Exams', value: '${prediction.mockExamsTaken}'),
            _BasedOnChip(label: 'Daily Topics', value: '${prediction.dailyTopicsCompleted}'),
            _BasedOnChip(label: 'Weak Areas', value: '${prediction.weakAreasCount}'),
          ]),
        ],
      ),
    );
  }
}

class _BasedOnChip extends StatelessWidget {
  final String label;
  final String value;
  const _BasedOnChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kMockDark)),
    );
  }
}

class _AdvancedAnalyticsSection extends StatelessWidget {
  final MockExamAnalytics analytics;
  const _AdvancedAnalyticsSection({required this.analytics});

  Color _colorFor(double pct) => pct >= 70 ? _kGreen : pct >= 50 ? _kAmber : _kRed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topics = analytics.topicMastery.map((t) => t.topic).toSet().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Topic mastery
        const Text('Topic Mastery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kGrey)),
        const SizedBox(height: 8),
        ...analytics.topicMastery.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(
                  width: 90,
                  child: Text(t.topic, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: t.masteryPercent / 100, minHeight: 10,
                      backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                      color: _colorFor(t.masteryPercent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text('${t.masteryPercent.round()}%',
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _colorFor(t.masteryPercent))),
                ),
              ]),
            )),

        const SizedBox(height: 20),
        // Difficulty trend
        const Text('Difficulty Trend', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kGrey)),
        const SizedBox(height: 10),
        Row(
          children: analytics.difficultyTrend.map((d) {
            final label = d.difficulty[0].toUpperCase() + d.difficulty.substring(1);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(children: [
                  Text('${d.avgPercent.round()}%',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _colorFor(d.avgPercent))),
                  const SizedBox(height: 6),
                  Container(
                    height: 60, width: double.infinity,
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FractionallySizedBox(
                      heightFactor: (d.avgPercent / 100).clamp(0.04, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _colorFor(d.avgPercent),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          }).toList(),
        ),

        if (topics.isNotEmpty && analytics.heatmap.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Topic × Difficulty Heat Map',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kGrey)),
          const SizedBox(height: 10),
          _HeatmapGrid(topics: topics, cells: analytics.heatmap),
        ],
      ],
    );
  }
}

class _HeatmapGrid extends StatelessWidget {
  final List<String> topics;
  final List<HeatmapCell> cells;
  const _HeatmapGrid({required this.topics, required this.cells});

  static const _difficulties = ['easy', 'medium', 'hard'];

  Color _colorFor(double? pct) {
    if (pct == null) return Colors.grey.withOpacity(0.08);
    if (pct >= 70) return _kGreen.withOpacity(0.25 + pct / 200);
    if (pct >= 50) return _kAmber.withOpacity(0.25 + pct / 200);
    return _kRed.withOpacity(0.25 + pct / 200);
  }

  @override
  Widget build(BuildContext context) {
    final lookup = <String, double>{};
    for (final c in cells) {
      lookup['${c.topic}|${c.difficulty}'] = c.percent;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const SizedBox(width: 100),
            ..._difficulties.map((d) => SizedBox(
                  width: 64, height: 24,
                  child: Center(
                    child: Text(d[0].toUpperCase() + d.substring(1),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                )),
          ]),
          ...topics.map((topic) => Row(children: [
                SizedBox(
                  width: 100,
                  child: Text(topic, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                ),
                ..._difficulties.map((d) {
                  final pct = lookup['$topic|$d'];
                  return Container(
                    width: 60, height: 32,
                    margin: const EdgeInsets.all(2),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _colorFor(pct),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(pct != null ? '${pct.round()}%' : '—',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                  );
                }),
              ])),
        ],
      ),
    );
  }
}

class _AchievementsRow extends StatelessWidget {
  final List<Achievement> achievements;
  const _AchievementsRow({required this.achievements});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: achievements.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final a = achievements[i];
          return Container(
            width: 92,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: a.unlocked
                  ? Colors.amber.withOpacity(0.12)
                  : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: a.unlocked ? Colors.amber.withOpacity(0.4)
                      : (isDark ? Colors.white12 : Colors.grey.shade200)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: a.unlocked ? 1 : 0.35,
                  child: Text(a.emoji, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(height: 6),
                Text(a.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: a.unlocked ? (isDark ? Colors.white : Colors.black87) : Colors.grey)),
                if (!a.unlocked) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: a.target > 0 ? a.progress / a.target : 0,
                      minHeight: 4,
                      backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                      color: _kMockPrimary,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45)),
        ],
      ),
    );
  }
}

class _WeakTopicRow extends StatelessWidget {
  final WeakTopic       topic;
  final VoidCallback    onLearn;
  const _WeakTopicRow({required this.topic, required this.onLearn});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final frac   = topic.total > 0 ? topic.correct / topic.total : 0.0;
    final color  = frac >= 0.7 ? _kGreen : frac >= 0.5 ? _kAmber : _kRed;
    final correctLabel = topic.correct == topic.correct.roundToDouble()
        ? topic.correct.round().toString() : topic.correct.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(topic.topic,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
            Text('$correctLabel/${topic.total} · ${topic.percent.round()}%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: frac, minHeight: 7,
              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
              color: color,
            ),
          ),
          if (topic.isWeak) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: OutlinedButton.icon(
                onPressed: onLearn,
                style: OutlinedButton.styleFrom(
                    foregroundColor: _kMockPrimary,
                    side: const BorderSide(color: _kMockPrimary),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                icon: const Icon(Icons.school_rounded, size: 14),
                label: const Text('Learn this Topic',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final MockExamHistoryItem item;
  const _HistoryRow({required this.item});

  Color get _gradeColor => switch (item.grade) {
    'A' || 'B' => _kGreen,
    'C' || 'D' => _kAmber,
    _          => _kRed,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date   = item.submittedAt ?? item.startedAt;
    final dateLabel = DateFormat('MMM d, y · h:mm a').format(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: _gradeColor.withOpacity(0.15), shape: BoxShape.circle),
          child: Center(
            child: Text(item.grade ?? '—',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _gradeColor)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.courseTitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(dateLabel, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(item.scorePercent != null ? '${item.scorePercent!.round()}%' : '—',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 2),
            Text(item.timeUsedLabel, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
      ]),
    );
  }
}

// ── Clean line chart (no external chart dependency) ──────────────────────────

class _ScoreProgressionChart extends StatelessWidget {
  final List<double> scores;   // chronological order, oldest first
  const _ScoreProgressionChart({required this.scores});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (scores.length < 2) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
        ),
        child: Text('Take a few more mock exams to see your progress trend.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      );
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: CustomPaint(
        size: Size.infinite,
        painter: _LineChartPainter(
          scores: scores,
          lineColor: _kMockPrimary,
          gridColor: isDark ? Colors.white12 : Colors.grey.shade300,
          labelColor: isDark ? Colors.white54 : Colors.black45,
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> scores;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;

  _LineChartPainter({
    required this.scores, required this.lineColor,
    required this.gridColor, required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 32.0;
    const bottomPad = 18.0;
    final chartWidth  = size.width - leftPad;
    final chartHeight = size.height - bottomPad;

    // Gridlines + Y labels at 0/50/100
    final gridPaint = Paint()..color = gridColor..strokeWidth = 1;
    for (final pct in [0, 50, 100]) {
      final y = chartHeight - (pct / 100) * chartHeight;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: '$pct%', style: TextStyle(fontSize: 9, color: labelColor)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // Line + points
    final path = Path();
    final points = <Offset>[];
    for (int i = 0; i < scores.length; i++) {
      final x = leftPad + (scores.length == 1 ? 0 : (i / (scores.length - 1)) * chartWidth);
      final y = chartHeight - (scores[i].clamp(0, 100) / 100) * chartHeight;
      points.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Gradient fill under the line
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, chartHeight)
      ..lineTo(points.first.dx, chartHeight)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [lineColor.withOpacity(0.22), lineColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = lineColor;
    final dotBorder = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2;
    for (final p in points) {
      canvas.drawCircle(p, 4, dotPaint);
      canvas.drawCircle(p, 4, dotBorder);
    }

    // First/last score labels
    if (points.isNotEmpty) {
      _drawScoreLabel(canvas, points.first, scores.first, labelColor);
      _drawScoreLabel(canvas, points.last, scores.last, labelColor);
    }
  }

  void _drawScoreLabel(Canvas canvas, Offset p, double score, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: '${score.round()}%',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dy = p.dy < 16 ? p.dy + 8 : p.dy - 18;
    tp.paint(canvas, Offset(p.dx - tp.width / 2, dy));
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.scores != scores;
}
