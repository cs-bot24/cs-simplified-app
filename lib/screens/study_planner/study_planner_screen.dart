// lib/screens/study_planner/study_planner_screen.dart
//
// AI-powered Study Planner — fully theme-aware (light + dark).

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/fcm_service.dart';
import '../../providers/study_planner_provider.dart';

// ── Accent color (brand, not theme-dependent) ─────────────────────────────────
const _kAccent   = Color(0xFF6C63FF);
const _kAccentLt = Color(0xFF8B85FF);
const _kGreen    = Color(0xFF4CAF50);

// ── Theme helpers (call inside build) ────────────────────────────────────────
Color _bg(BuildContext ctx)  => Theme.of(ctx).scaffoldBackgroundColor;
Color _surface(BuildContext ctx) => Theme.of(ctx).cardColor;
Color _surface2(BuildContext ctx) {
  final isDark = Theme.of(ctx).brightness == Brightness.dark;
  return isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
}
Color _textPri(BuildContext ctx) => Theme.of(ctx).colorScheme.onSurface;
Color _textSec(BuildContext ctx) {
  final isDark = Theme.of(ctx).brightness == Brightness.dark;
  return isDark ? const Color(0xFFAAAAAA) : Colors.black54;
}


// ══════════════════════════════════════════════════════════════════════════════
// Models
// ══════════════════════════════════════════════════════════════════════════════

class StudySession {
  final int     id;
  final int     planId;
  final String  title;
  final String? description;
  final DateTime scheduledDate;
  final int     durationMins;
  bool          isCompleted;
  DateTime?     completedAt;
  String?       notes;

  StudySession({
    required this.id,
    required this.planId,
    required this.title,
    this.description,
    required this.scheduledDate,
    required this.durationMins,
    required this.isCompleted,
    this.completedAt,
    this.notes,
  });

  factory StudySession.fromJson(Map<String, dynamic> j) => StudySession(
    id:            j['id'] as int,
    planId:        j['plan_id'] as int,
    title:         j['title'] as String,
    description:   j['description'] as String?,
    scheduledDate: DateTime.parse(j['scheduled_date'] as String),
    durationMins:  j['duration_mins'] as int,
    isCompleted:   j['is_completed'] as bool,
    completedAt:   j['completed_at'] != null
        ? DateTime.parse(j['completed_at'] as String)
        : null,
    notes:         j['notes'] as String?,
  );
}

class StudyPlan {
  final int      id;
  final String?  courseCode;
  final String   courseName;
  final String   title;
  final String?  goal;
  final DateTime startDate;
  final DateTime endDate;
  final int      studyHoursPerDay;
  final String?  aiPlan;
  final String   status;
  int            progress;
  final DateTime createdAt;
  final List<StudySession> sessions;

  StudyPlan({
    required this.id,
    this.courseCode,
    required this.courseName,
    required this.title,
    this.goal,
    required this.startDate,
    required this.endDate,
    required this.studyHoursPerDay,
    this.aiPlan,
    required this.status,
    required this.progress,
    required this.createdAt,
    required this.sessions,
  });

  factory StudyPlan.fromJson(Map<String, dynamic> j) => StudyPlan(
    id:               j['id'] as int,
    courseCode:       j['course_code'] as String?,
    courseName:       j['course_name'] as String,
    title:            j['title'] as String,
    goal:             j['goal'] as String?,
    startDate:        DateTime.parse(j['start_date'] as String),
    endDate:          DateTime.parse(j['end_date'] as String),
    studyHoursPerDay: j['study_hours_per_day'] as int,
    aiPlan:           j['ai_plan'] as String?,
    status:           j['status'] as String,
    progress:         j['progress'] as int,
    createdAt:        DateTime.parse(j['created_at'] as String),
    sessions:         (j['sessions'] as List)
        .map((s) => StudySession.fromJson(s as Map<String, dynamic>))
        .toList(),
  );

  List<StudySession> get todaySessions {
    final today = DateTime.now();
    return sessions.where((s) =>
      s.scheduledDate.year  == today.year  &&
      s.scheduledDate.month == today.month &&
      s.scheduledDate.day   == today.day,
    ).toList();
  }

  List<StudySession> get upcomingSessions => sessions
      .where((s) => !s.isCompleted &&
          s.scheduledDate.isAfter(DateTime.now()))
      .take(5)
      .toList();
}


// ══════════════════════════════════════════════════════════════════════════════
// Main Screen
// ══════════════════════════════════════════════════════════════════════════════

class StudyPlannerScreen extends StatefulWidget {
  const StudyPlannerScreen({super.key});

  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen>
    with SingleTickerProviderStateMixin {
  List<StudyPlan> _plans    = [];
  bool            _loading  = true;
  String?         _error;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.getStudyPlans();
      setState(() {
        _plans   = (data as List)
            .map((j) => StudyPlan.fromJson(j as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
      if (mounted) context.read<StudyPlannerProvider>().refresh();
    } catch (e) {
      setState(() { _error = 'Could not load plans.'; _loading = false; });
    }
  }

  void _openCreateSheet() async {
    final created = await showModalBottomSheet<StudyPlan>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreatePlanSheet(),
    );
    if (created != null) {
      setState(() => _plans.insert(0, created));
      _showSnack('Study plan created! 🎯', success: true);
      if (mounted) context.read<StudyPlannerProvider>().refresh();
    }
  }

  void _showSnack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green[700] : Colors.red[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Planner', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: _kAccentLt,
          unselectedLabelColor: _textSec(context),
          indicatorColor: _kAccent,
          tabs: const [
            Tab(text: 'My Plans'),
            Tab(text: 'Today'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        backgroundColor: _kAccent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Plan',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _PlansTab(plans: _plans, onRefresh: _load,
                        onDelete: _deletePlan),
                    _TodayTab(plans: _plans, onComplete: _completeSession),
                  ],
                ),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, color: _textSec(context), size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: TextStyle(color: _textSec(context))),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _load, child: const Text('Retry')),
      ],
    ),
  );

  Future<void> _deletePlan(int planId) async {
    try {
      await ApiClient.deleteStudyPlan(planId);
      setState(() => _plans.removeWhere((p) => p.id == planId));
      _showSnack('Plan deleted.', success: true);
      if (mounted) context.read<StudyPlannerProvider>().refresh();
    } catch (_) {
      _showSnack('Could not delete plan.', success: false);
    }
  }

  Future<void> _completeSession(StudyPlan plan, StudySession session) async {
    try {
      await ApiClient.completeStudySession(plan.id, session.id);
      setState(() {
        session.isCompleted = true;
        session.completedAt = DateTime.now();
        final total = plan.sessions.length;
        final done  = plan.sessions.where((s) => s.isCompleted).length;
        plan.progress = total > 0 ? ((done / total) * 100).round() : 0;
      });
      if (mounted) {
        final planner = context.read<StudyPlannerProvider>();
        planner.markCompletedLocally(session.id);
        planner.refresh();
      }
      await FcmService.showStudyReminder(
        id:    session.id,
        title: '✅ Session Complete!',
        body:  '${session.title} — great work! Keep it up.',
      );
      _showSnack('Session marked complete! ✅', success: true);
    } catch (_) {
      _showSnack('Could not update session.', success: false);
    }
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// Plans Tab
// ══════════════════════════════════════════════════════════════════════════════

class _PlansTab extends StatelessWidget {
  final List<StudyPlan> plans;
  final VoidCallback    onRefresh;
  final void Function(int planId) onDelete;

  const _PlansTab({
    required this.plans,
    required this.onRefresh,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_rounded,
                  color: _kAccent.withOpacity(0.4), size: 56),
              const SizedBox(height: 16),
              Text('No study plans yet',
                  style: TextStyle(color: _textPri(context), fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'Tap "New Plan" to let AI create a personalised\nstudy schedule for your course.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSec(context), fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: _kAccentLt,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: plans.length,
        itemBuilder: (_, i) => _PlanCard(
          plan: plans[i],
          onDelete: () => onDelete(plans[i].id),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final StudyPlan    plan;
  final VoidCallback onDelete;
  const _PlanCard({required this.plan, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final total    = plan.sessions.length;
    final done     = plan.sessions.where((s) => s.isCompleted).length;
    final daysLeft = plan.endDate.difference(DateTime.now()).inDays;
    final isActive = plan.status == 'active';
    final fmt      = DateFormat('MMM d');

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => _PlanDetailScreen(plan: plan),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: plan.progress == 100
                ? _kGreen.withOpacity(0.4)
                : _kAccent.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (plan.courseCode != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(plan.courseCode!,
                                style: const TextStyle(
                                    color: _kAccentLt, fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        Text(plan.title,
                            style: TextStyle(
                                color: _textPri(context), fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(plan.courseName,
                            style: TextStyle(
                                color: _textSec(context), fontSize: 12)),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded,
                        color: _textSec(context), size: 20),
                    onSelected: (val) {
                      if (val == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline_rounded,
                                color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ])),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$done / $total sessions',
                          style: TextStyle(
                              color: _textSec(context), fontSize: 12)),
                      Text('${plan.progress}%',
                          style: TextStyle(
                              color: plan.progress == 100
                                  ? _kGreen
                                  : _kAccentLt,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: plan.progress / 100,
                      backgroundColor: _surface2(context),
                      valueColor: AlwaysStoppedAnimation(
                        plan.progress == 100 ? _kGreen : _kAccent,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded,
                      color: _textSec(context), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${fmt.format(plan.startDate)} – ${fmt.format(plan.endDate)}',
                    style: TextStyle(color: _textSec(context), fontSize: 12),
                  ),
                  const Spacer(),
                  if (plan.progress == 100)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Completed ✓',
                          style: TextStyle(color: _kGreen, fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    )
                  else if (isActive && daysLeft >= 0)
                    Text('$daysLeft days left',
                        style: TextStyle(
                            color: daysLeft <= 3
                                ? Colors.orange
                                : _textSec(context),
                            fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// Today Tab
// ══════════════════════════════════════════════════════════════════════════════

class _TodayTab extends StatelessWidget {
  final List<StudyPlan> plans;
  final void Function(StudyPlan, StudySession) onComplete;
  const _TodayTab({required this.plans, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final todaySessions = <MapEntry<StudyPlan, StudySession>>[];
    for (final plan in plans) {
      for (final s in plan.todaySessions) {
        todaySessions.add(MapEntry(plan, s));
      }
    }
    todaySessions.sort((a, b) => a.value.isCompleted ? 1 : -1);

    final today = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        Text(today, style: TextStyle(color: _textSec(context), fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          todaySessions.isEmpty
              ? 'No sessions today'
              : "${todaySessions.length} session${todaySessions.length > 1 ? 's' : ''} scheduled",
          style: TextStyle(color: _textPri(context), fontSize: 20,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        if (todaySessions.isEmpty)
          _buildEmptyToday(context)
        else
          ...todaySessions.map((entry) => _SessionCard(
            plan:       entry.key,
            session:    entry.value,
            onComplete: () => onComplete(entry.key, entry.value),
          )),
      ],
    );
  }

  Widget _buildEmptyToday(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _surface(context),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Icon(Icons.coffee_rounded, color: _kAccent.withOpacity(0.4), size: 40),
        const SizedBox(height: 12),
        Text('No sessions today',
            style: TextStyle(color: _textPri(context), fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Enjoy your rest day or create a new study plan.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSec(context), fontSize: 13)),
      ],
    ),
  );
}

class _SessionCard extends StatelessWidget {
  final StudyPlan    plan;
  final StudySession session;
  final VoidCallback onComplete;
  const _SessionCard({
    required this.plan,
    required this.session,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: session.isCompleted
              ? _kGreen.withOpacity(0.3)
              : _kAccent.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: GestureDetector(
          onTap: session.isCompleted ? null : onComplete,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: session.isCompleted
                  ? _kGreen
                  : _kAccent.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: session.isCompleted ? _kGreen : _kAccent,
                width: 2,
              ),
            ),
            child: session.isCompleted
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 18)
                : null,
          ),
        ),
        title: Text(
          session.title,
          style: TextStyle(
            color: session.isCompleted ? _textSec(context) : _textPri(context),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            decoration: session.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              if (plan.courseCode != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(plan.courseCode!,
                      style: const TextStyle(
                          color: _kAccentLt, fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
              ],
              Icon(Icons.timer_outlined, color: _textSec(context), size: 13),
              const SizedBox(width: 3),
              Text('${session.durationMins} min',
                  style: TextStyle(color: _textSec(context), fontSize: 12)),
            ],
          ),
        ),
        trailing: session.isCompleted
            ? const Text('Done',
                style: TextStyle(color: _kGreen, fontSize: 12,
                    fontWeight: FontWeight.w600))
            : TextButton(
                onPressed: onComplete,
                style: TextButton.styleFrom(
                  backgroundColor: _kAccent.withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                ),
                child: const Text('Done',
                    style: TextStyle(color: _kAccentLt,
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// Plan Detail Screen
// ══════════════════════════════════════════════════════════════════════════════

class _PlanDetailScreen extends StatelessWidget {
  final StudyPlan plan;
  const _PlanDetailScreen({required this.plan});

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<StudySession>>{};
    for (final s in plan.sessions) {
      final key = DateFormat('yyyy-MM-dd').format(s.scheduledDate);
      grouped.putIfAbsent(key, () => []).add(s);
    }
    final dates = grouped.keys.toList()..sort();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            if (plan.courseCode != null)
              Text(plan.courseCode!,
                  style: TextStyle(color: _textSec(context), fontSize: 11)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProgressCard(plan: plan),
          const SizedBox(height: 16),

          if (plan.aiPlan != null && plan.aiPlan!.isNotEmpty) ...[
            Text('AI Study Plan',
                style: TextStyle(color: _textPri(context), fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kAccent.withOpacity(0.2)),
              ),
              child: MarkdownBody(
                data: plan.aiPlan!,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                      color: isDark ? const Color(0xFFDDDDDD) : Colors.black87,
                      fontSize: 13, height: 1.5),
                  h1: TextStyle(color: _textPri(context), fontSize: 16,
                      fontWeight: FontWeight.bold),
                  h2: TextStyle(color: _textPri(context), fontSize: 14,
                      fontWeight: FontWeight.bold),
                  h3: TextStyle(color: _textPri(context), fontSize: 13,
                      fontWeight: FontWeight.w600),
                  strong: TextStyle(color: _textPri(context),
                      fontWeight: FontWeight.bold),
                  listBullet: TextStyle(color: _textSec(context)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          Text('Sessions',
              style: TextStyle(color: _textPri(context), fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...dates.map((dateKey) {
            final sessions = grouped[dateKey]!;
            final date     = DateTime.parse(dateKey);
            final isToday  = _isToday(date);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, top: 4),
                  child: Row(
                    children: [
                      Text(
                        DateFormat('EEE, MMM d').format(date),
                        style: TextStyle(
                          color: isToday ? _kAccentLt : _textSec(context),
                          fontSize: 12,
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: _kAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Today',
                              style: TextStyle(color: _kAccentLt,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ),
                ...sessions.map((s) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _surface(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: s.isCompleted
                          ? _kGreen.withOpacity(0.3)
                          : _surface2(context).withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        s.isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: s.isCompleted ? _kGreen : _textSec(context),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(s.title,
                            style: TextStyle(
                              color: s.isCompleted
                                  ? _textSec(context)
                                  : _textPri(context),
                              fontSize: 13,
                              decoration: s.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            )),
                      ),
                      Text('${s.durationMins}m',
                          style: TextStyle(
                              color: _textSec(context), fontSize: 12)),
                    ],
                  ),
                )),
                const SizedBox(height: 6),
              ],
            );
          }),
        ],
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

class _ProgressCard extends StatelessWidget {
  final StudyPlan plan;
  const _ProgressCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final total = plan.sessions.length;
    final done  = plan.sessions.where((s) => s.isCompleted).length;
    final days  = plan.endDate.difference(DateTime.now()).inDays;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kAccent.withOpacity(0.3), _surface(context)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${plan.progress}% Complete',
                  style: TextStyle(color: _textPri(context), fontSize: 16,
                      fontWeight: FontWeight.w700)),
              Text(
                plan.progress == 100
                    ? '🎉 Completed!'
                    : days >= 0
                        ? '$days days left'
                        : 'Overdue',
                style: TextStyle(
                  color: plan.progress == 100
                      ? _kGreen
                      : days <= 3 && days >= 0
                          ? Colors.orange
                          : days < 0
                              ? Colors.red
                              : _textSec(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: plan.progress / 100,
              backgroundColor: _surface2(context),
              valueColor: AlwaysStoppedAnimation(
                  plan.progress == 100 ? _kGreen : _kAccent),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Stat(label: 'Sessions', value: '$done/$total', context: context),
              const SizedBox(width: 20),
              _Stat(label: 'Hours/day',
                  value: '${plan.studyHoursPerDay}h', context: context),
              const SizedBox(width: 20),
              _Stat(
                  label: 'Status',
                  value: plan.status[0].toUpperCase() +
                      plan.status.substring(1),
                  context: context),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final BuildContext context;
  const _Stat({required this.label, required this.value, required this.context});

  @override
  Widget build(BuildContext ctx) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: _textSec(context), fontSize: 11)),
      Text(value, style: TextStyle(color: _textPri(context), fontSize: 14,
          fontWeight: FontWeight.w600)),
    ],
  );
}


// ══════════════════════════════════════════════════════════════════════════════
// Create Plan Bottom Sheet
// ══════════════════════════════════════════════════════════════════════════════

class _CreatePlanSheet extends StatefulWidget {
  const _CreatePlanSheet();

  @override
  State<_CreatePlanSheet> createState() => _CreatePlanSheetState();
}

class _CreatePlanSheetState extends State<_CreatePlanSheet> {
  final _courseCodeCtrl = TextEditingController();
  final _courseNameCtrl = TextEditingController();
  final _titleCtrl      = TextEditingController();
  final _goalCtrl       = TextEditingController();

  DateTime _startDate    = DateTime.now();
  DateTime _endDate      = DateTime.now().add(const Duration(days: 30));
  int      _hoursPerDay  = 2;
  bool     _loading      = false;
  String?  _error;

  @override
  void dispose() {
    _courseCodeCtrl.dispose();
    _courseNameCtrl.dispose();
    _titleCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => isDark
          ? Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(primary: _kAccent),
              ),
              child: child!,
            )
          : child!,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 30));
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _create() async {
    if (_courseNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Course name is required.');
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Plan title is required.');
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      setState(() => _error = 'End date must be after start date.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final data = await ApiClient.createStudyPlan(
        courseCode:       _courseCodeCtrl.text.trim().isEmpty
            ? null
            : _courseCodeCtrl.text.trim(),
        courseName:       _courseNameCtrl.text.trim(),
        title:            _titleCtrl.text.trim(),
        goal:             _goalCtrl.text.trim().isEmpty
            ? null
            : _goalCtrl.text.trim(),
        startDate:        _startDate,
        endDate:          _endDate,
        studyHoursPerDay: _hoursPerDay,
      );
      final plan = StudyPlan.fromJson(data as Map<String, dynamic>);
      if (mounted) Navigator.pop(context, plan);
    } catch (e) {
      setState(() {
        _error   = 'Could not create plan. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt    = DateFormat('MMM d, yyyy');
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                decoration: BoxDecoration(
                  color: _textSec(context).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kAccent, Color(0xFF9C27B0)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create Study Plan',
                        style: TextStyle(color: _textPri(context), fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    Text('AI will generate your schedule',
                        style: TextStyle(color: _textSec(context), fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
              const SizedBox(height: 12),
            ],

            _Field(
              label:      'Course Code (optional)',
              hint:       'e.g. MTH104',
              controller: _courseCodeCtrl,
              capitalize: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            _Field(
              label:      'Course Name *',
              hint:       'e.g. Linear Algebra II',
              controller: _courseNameCtrl,
            ),
            const SizedBox(height: 12),
            _Field(
              label:      'Plan Title *',
              hint:       'e.g. MTH104 Exam Prep',
              controller: _titleCtrl,
            ),
            const SizedBox(height: 12),
            _Field(
              label:      'Goal (optional)',
              hint:       'e.g. Pass MTH104 with a B grade',
              controller: _goalCtrl,
              maxLines:   2,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: _DateTile(
                  label: 'Start Date',
                  date:  fmt.format(_startDate),
                  onTap: () => _pickDate(isStart: true),
                )),
                const SizedBox(width: 10),
                Expanded(child: _DateTile(
                  label: 'End Date',
                  date:  fmt.format(_endDate),
                  onTap: () => _pickDate(isStart: false),
                )),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Text('Study hours per day:',
                    style: TextStyle(color: _textSec(context), fontSize: 13)),
                const Spacer(),
                IconButton(
                  onPressed: _hoursPerDay > 1
                      ? () => setState(() => _hoursPerDay--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      color: _kAccentLt),
                ),
                Text('$_hoursPerDay',
                    style: TextStyle(color: _textPri(context), fontSize: 16,
                        fontWeight: FontWeight.w700)),
                IconButton(
                  onPressed: _hoursPerDay < 8
                      ? () => setState(() => _hoursPerDay++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      color: _kAccentLt),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  disabledBackgroundColor: _kAccent.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Generate Plan with AI',
                              style: TextStyle(color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String              label;
  final String              hint;
  final TextEditingController controller;
  final int                 maxLines;
  final TextCapitalization  capitalize;

  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines   = 1,
    this.capitalize = TextCapitalization.sentences,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: _textSec(context), fontSize: 12)),
      const SizedBox(height: 4),
      TextField(
        controller:         controller,
        maxLines:           maxLines,
        textCapitalization: capitalize,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
        ),
      ),
    ],
  );
}

class _DateTile extends StatelessWidget {
  final String label;
  final String date;
  final VoidCallback onTap;
  const _DateTile({required this.label, required this.date,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _surface2(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: _textSec(context), fontSize: 11)),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  color: _kAccentLt, size: 14),
              const SizedBox(width: 5),
              Text(date,
                  style: TextStyle(color: _textPri(context), fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    ),
  );
}
