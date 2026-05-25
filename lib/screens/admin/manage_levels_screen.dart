import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/academic_provider.dart';
import '../../models/level_model.dart';
import '../../models/semester_model.dart';

class ManageLevelsScreen extends StatefulWidget {
  const ManageLevelsScreen({super.key});
  @override State<ManageLevelsScreen> createState() => _ManageLevelsScreenState();
}

class _ManageLevelsScreenState extends State<ManageLevelsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademicProvider>().fetchLevels();
    });
  }

  Future<void> _addLevel() async {
    final nameCtrl  = TextEditingController();
    final emojiCtrl = TextEditingController(text: '🎓');
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Level'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Level Name (e.g. 300 Level)')),
          const SizedBox(height: 12),
          TextField(controller: emojiCtrl,
              decoration: const InputDecoration(labelText: 'Emoji')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (result == true && nameCtrl.text.isNotEmpty) {
      try {
        await ApiClient.createLevel({
          'level_name': nameCtrl.text.trim(),
          'emoji': emojiCtrl.text.trim(),
          'sort_order': 0,
        });
        if (mounted) {
          context.read<AcademicProvider>().fetchLevels();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Level added successfully')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _addSemester(LevelModel level) async {
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add Semester to ${level.levelName}'),
        content: TextField(controller: ctrl,
            decoration: const InputDecoration(
                labelText: 'Semester Name (e.g. First Semester)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (result == true && ctrl.text.isNotEmpty) {
      try {
        await ApiClient.createSemester({
          'level_id': level.id,
          'semester_name': ctrl.text.trim(),
          'sort_order': 0,
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semester added successfully')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _addCourse(SemesterModel sem) async {
    final codeCtrl  = TextEditingController();
    final titleCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add Course to ${sem.semesterName}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: codeCtrl,
              decoration: const InputDecoration(labelText: 'Course Code (e.g. COSC 301)')),
          const SizedBox(height: 12),
          TextField(controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Course Title (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (result == true && codeCtrl.text.isNotEmpty) {
      try {
        await ApiClient.createCourse({
          'semester_id': sem.id,
          'course_code': codeCtrl.text.trim().toUpperCase(),
          'course_title': titleCtrl.text.trim(),
          'sort_order': 0,
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course added successfully')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final academic = context.watch<AcademicProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Levels & Courses'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _addLevel,
              tooltip: 'Add Level'),
        ],
      ),
      body: academic.levels.isEmpty
          ? const Center(child: Text('No levels yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: academic.levels.length,
              itemBuilder: (ctx, i) {
                final level = academic.levels[i];
                return _LevelExpansion(
                  level: level,
                  onAddSemester: () => _addSemester(level),
                  onAddCourse: _addCourse,
                );
              },
            ),
    );
  }
}

class _LevelExpansion extends StatefulWidget {
  final LevelModel level;
  final VoidCallback onAddSemester;
  final Function(SemesterModel) onAddCourse;
  const _LevelExpansion({required this.level, required this.onAddSemester,
      required this.onAddCourse});
  @override State<_LevelExpansion> createState() => _LevelExpansionState();
}

class _LevelExpansionState extends State<_LevelExpansion> {
  List<SemesterModel> _semesters = [];
  bool _loading = false;

  Future<void> _loadSemesters() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.getSemesters(widget.level.id);
      _semesters = data.map((e) => SemesterModel.fromJson(e)).toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Text(widget.level.emoji, style: const TextStyle(fontSize: 24)),
        title: Text(widget.level.levelName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        onExpansionChanged: (open) { if (open) _loadSemesters(); },
        children: [
          if (_loading)
            const Padding(padding: EdgeInsets.all(16),
                child: CircularProgressIndicator()),
          ..._semesters.map((sem) => _SemesterTile(
                sem: sem,
                onAddCourse: () => widget.onAddCourse(sem),
              )),
          ListTile(
            leading: Icon(Icons.add_circle_outline, color: scheme.primary),
            title: Text('Add Semester', style: TextStyle(color: scheme.primary)),
            onTap: () { widget.onAddSemester(); _loadSemesters(); },
          ),
        ],
      ),
    );
  }
}

class _SemesterTile extends StatefulWidget {
  final SemesterModel sem;
  final VoidCallback onAddCourse;
  const _SemesterTile({required this.sem, required this.onAddCourse});
  @override State<_SemesterTile> createState() => _SemesterTileState();
}

class _SemesterTileState extends State<_SemesterTile> {
  List courses = [];

  Future<void> _load() async {
    try {
      courses = await ApiClient.getCourses(widget.sem.id);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExpansionTile(
      leading: const Icon(Icons.calendar_today_rounded, size: 20),
      title: Text(widget.sem.semesterName, style: const TextStyle(fontSize: 14)),
      onExpansionChanged: (open) { if (open) _load(); },
      children: [
        ...courses.map((c) => ListTile(
          dense: true,
          leading: const Icon(Icons.book_outlined, size: 18),
          title: Text(c['course_code'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: c['course_title'] != null && c['course_title'] != ''
              ? Text(c['course_title'], style: const TextStyle(fontSize: 11))
              : null,
        )),
        ListTile(
          dense: true,
          leading: Icon(Icons.add, color: scheme.primary, size: 18),
          title: Text('Add Course', style: TextStyle(color: scheme.primary, fontSize: 13)),
          onTap: () { widget.onAddCourse(); _load(); },
        ),
      ],
    );
  }
}
