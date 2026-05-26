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
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        context.read<AcademicProvider>().fetchLevels());
  }

  // ── Level dialogs ─────────────────────────────────────────────────────────

  Future<void> _addLevel() async {
    final nameCtrl  = TextEditingController();
    final emojiCtrl = TextEditingController(text: '🎓');
    final ok = await _showFormDialog(
      title: 'Add Level',
      fields: [
        _Field(ctrl: nameCtrl,  label: 'Level Name (e.g. 300 Level)'),
        _Field(ctrl: emojiCtrl, label: 'Emoji'),
      ],
    );
    if (!ok || nameCtrl.text.trim().isEmpty) return;
    await _run(() => ApiClient.createLevel({
      'level_name': nameCtrl.text.trim(),
      'emoji': emojiCtrl.text.trim().isEmpty ? '🎓' : emojiCtrl.text.trim(),
      'sort_order': 0,
    }), successMsg: 'Level added', then: () => context.read<AcademicProvider>().fetchLevels());
  }

  Future<void> _editLevel(LevelModel level) async {
    final nameCtrl  = TextEditingController(text: level.levelName);
    final emojiCtrl = TextEditingController(text: level.emoji);
    final ok = await _showFormDialog(
      title: 'Edit Level',
      fields: [
        _Field(ctrl: nameCtrl,  label: 'Level Name'),
        _Field(ctrl: emojiCtrl, label: 'Emoji'),
      ],
    );
    if (!ok || nameCtrl.text.trim().isEmpty) return;
    await _run(() => ApiClient.updateLevel(level.id, {
      'level_name': nameCtrl.text.trim(),
      'emoji': emojiCtrl.text.trim(),
      'sort_order': level.sortOrder,
    }), successMsg: 'Level updated', then: () => context.read<AcademicProvider>().fetchLevels());
  }

  Future<void> _deleteLevel(LevelModel level) async {
    final ok = await _confirmDelete('Delete "${level.levelName}"?',
        'This will also delete all semesters and courses inside it.');
    if (!ok) return;
    await _run(() => ApiClient.deleteLevel(level.id),
        successMsg: 'Level deleted',
        then: () => context.read<AcademicProvider>().fetchLevels());
  }

  // ── Semester dialogs ──────────────────────────────────────────────────────

  Future<void> _addSemester(LevelModel level) async {
    final ctrl = TextEditingController();
    final ok = await _showFormDialog(
      title: 'Add Semester to ${level.levelName}',
      fields: [_Field(ctrl: ctrl, label: 'Semester Name (e.g. First Semester)')],
    );
    if (!ok || ctrl.text.trim().isEmpty) return;
    await _run(() => ApiClient.createSemester({
      'level_id': level.id,
      'semester_name': ctrl.text.trim(),
      'sort_order': 0,
    }), successMsg: 'Semester added');
  }

  Future<void> _editSemester(SemesterModel sem) async {
    final ctrl = TextEditingController(text: sem.semesterName);
    final ok = await _showFormDialog(
      title: 'Edit Semester',
      fields: [_Field(ctrl: ctrl, label: 'Semester Name')],
    );
    if (!ok || ctrl.text.trim().isEmpty) return;
    await _run(() => ApiClient.updateSemester(sem.id, {
      'semester_name': ctrl.text.trim(),
      'level_id': sem.levelId,
      'sort_order': sem.sortOrder,
    }), successMsg: 'Semester updated');
  }

  Future<void> _deleteSemester(SemesterModel sem) async {
    final ok = await _confirmDelete('Delete "${sem.semesterName}"?',
        'This will also delete all courses inside it.');
    if (!ok) return;
    await _run(() => ApiClient.deleteSemester(sem.id), successMsg: 'Semester deleted');
  }

  // ── Course dialogs ────────────────────────────────────────────────────────

  Future<void> _addCourse(SemesterModel sem) async {
    final codeCtrl  = TextEditingController();
    final titleCtrl = TextEditingController();
    final ok = await _showFormDialog(
      title: 'Add Course to ${sem.semesterName}',
      fields: [
        _Field(ctrl: codeCtrl,  label: 'Course Code (e.g. COSC 301)'),
        _Field(ctrl: titleCtrl, label: 'Course Title (optional)'),
      ],
    );
    if (!ok || codeCtrl.text.trim().isEmpty) return;
    await _run(() => ApiClient.createCourse({
      'semester_id': sem.id,
      'course_code': codeCtrl.text.trim().toUpperCase(),
      'course_title': titleCtrl.text.trim(),
      'sort_order': 0,
    }), successMsg: 'Course added');
  }

  Future<void> _editCourse(Map<String, dynamic> course) async {
    final codeCtrl  = TextEditingController(text: course['course_code'] ?? '');
    final titleCtrl = TextEditingController(text: course['course_title'] ?? '');
    final ok = await _showFormDialog(
      title: 'Edit Course',
      fields: [
        _Field(ctrl: codeCtrl,  label: 'Course Code'),
        _Field(ctrl: titleCtrl, label: 'Course Title (optional)'),
      ],
    );
    if (!ok || codeCtrl.text.trim().isEmpty) return;
    await _run(() => ApiClient.updateCourse(course['id'], {
      'course_code': codeCtrl.text.trim().toUpperCase(),
      'course_title': titleCtrl.text.trim(),
      'semester_id': course['semester_id'],
      'sort_order': course['sort_order'] ?? 0,
    }), successMsg: 'Course updated');
  }

  Future<void> _deleteCourse(Map<String, dynamic> course) async {
    final ok = await _confirmDelete('Delete "${course['course_code']}"?', null);
    if (!ok) return;
    await _run(() => ApiClient.deleteCourse(course['id']), successMsg: 'Course deleted');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _run(Future Function() fn,
      {required String successMsg, VoidCallback? then}) async {
    try {
      await fn();
      if (mounted) {
        _snack(successMsg, success: true);
        then?.call();
      }
    } catch (e) {
      if (mounted) _snack(e.toString(), success: false);
    }
  }

  void _snack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(success ? Icons.check_circle : Icons.error_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: success ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<bool> _showFormDialog({
    required String title,
    required List<_Field> fields,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: fields.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: f.ctrl,
                decoration: InputDecoration(
                  labelText: f.label,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    return result == true;
  }

  Future<bool> _confirmDelete(String title, String? subtitle) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: subtitle != null ? Text(subtitle) : null,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final academic = context.watch<AcademicProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Levels & Courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _addLevel,
            tooltip: 'Add Level',
          ),
        ],
      ),
      body: academic.loading
          ? const Center(child: CircularProgressIndicator())
          : academic.levels.isEmpty
              ? _EmptyState(onAdd: _addLevel)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: academic.levels.length,
                  itemBuilder: (ctx, i) {
                    final level = academic.levels[i];
                    return _LevelCard(
                      level: level,
                      onEdit: () => _editLevel(level),
                      onDelete: () => _deleteLevel(level),
                      onAddSemester: () => _addSemester(level),
                      onEditSemester: _editSemester,
                      onDeleteSemester: _deleteSemester,
                      onAddCourse: _addCourse,
                      onEditCourse: _editCourse,
                      onDeleteCourse: _deleteCourse,
                    );
                  },
                ),
    );
  }
}

// ── Supporting types ──────────────────────────────────────────────────────────

class _Field {
  final TextEditingController ctrl;
  final String label;
  _Field({required this.ctrl, required this.label});
}

// ── Level card with edit/delete ───────────────────────────────────────────────

class _LevelCard extends StatefulWidget {
  final LevelModel level;
  final VoidCallback onEdit, onDelete, onAddSemester;
  final Function(SemesterModel) onEditSemester, onDeleteSemester, onAddCourse;
  final Function(Map<String, dynamic>) onEditCourse, onDeleteCourse;

  const _LevelCard({
    required this.level,
    required this.onEdit, required this.onDelete,
    required this.onAddSemester,
    required this.onEditSemester, required this.onDeleteSemester,
    required this.onAddCourse,
    required this.onEditCourse, required this.onDeleteCourse,
  });

  @override State<_LevelCard> createState() => _LevelCardState();
}

class _LevelCardState extends State<_LevelCard> {
  List<SemesterModel> _semesters = [];
  bool _loading = false;
  bool _expanded = false;

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          // Level header row
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (_expanded) _loadSemesters();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(widget.level.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.level.levelName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  // Edit button
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        size: 18, color: scheme.primary),
                    onPressed: widget.onEdit,
                    tooltip: 'Edit Level',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  // Delete button
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    onPressed: widget.onDelete,
                    tooltip: 'Delete Level',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  Icon(_expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey[400]),
                ],
              ),
            ),
          ),

          // Expanded semester list
          if (_expanded) ...[
            const Divider(height: 1),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              ..._semesters.map((sem) => _SemesterTile(
                sem: sem,
                onEdit: () async {
                  await widget.onEditSemester(sem);
                  _loadSemesters();
                },
                onDelete: () async {
                  await widget.onDeleteSemester(sem);
                  _loadSemesters();
                },
                onAddCourse: () async {
                  await widget.onAddCourse(sem);
                },
                onEditCourse: widget.onEditCourse,
                onDeleteCourse: widget.onDeleteCourse,
              )),
              // Add semester
              InkWell(
                onTap: () async {
                  await widget.onAddSemester();
                  _loadSemesters();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Icon(Icons.add_circle_outline,
                        color: scheme.primary, size: 18),
                    const SizedBox(width: 10),
                    Text('Add Semester',
                        style: TextStyle(
                            color: scheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Semester tile with edit/delete ────────────────────────────────────────────

class _SemesterTile extends StatefulWidget {
  final SemesterModel sem;
  final VoidCallback onEdit, onDelete, onAddCourse;
  final Function(Map<String, dynamic>) onEditCourse, onDeleteCourse;

  const _SemesterTile({
    required this.sem,
    required this.onEdit, required this.onDelete,
    required this.onAddCourse,
    required this.onEditCourse, required this.onDeleteCourse,
  });

  @override State<_SemesterTile> createState() => _SemesterTileState();
}

class _SemesterTileState extends State<_SemesterTile> {
  List<dynamic> _courses = [];
  bool _expanded = false;
  bool _loading = false;

  Future<void> _loadCourses() async {
    setState(() => _loading = true);
    try {
      _courses = await ApiClient.getCourses(widget.sem.id);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: scheme.primary.withOpacity(0.3), width: 3),
        ),
        color: scheme.primary.withOpacity(0.02),
      ),
      child: Column(
        children: [
          // Semester row
          InkWell(
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (_expanded) _loadCourses();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.sem.semesterName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        size: 16, color: scheme.primary),
                    onPressed: widget.onEdit,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Colors.red),
                    onPressed: widget.onDelete,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  Icon(_expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      size: 18, color: Colors.grey[400]),
                ],
              ),
            ),
          ),

          // Courses list
          if (_expanded) ...[
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2))
            else ...[
              ..._courses.map((c) => Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 12, 0),
                child: Row(
                  children: [
                    const Icon(Icons.book_outlined,
                        size: 14, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['course_code'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          if ((c['course_title'] ?? '').isNotEmpty)
                            Text(c['course_title'],
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined,
                          size: 14, color: scheme.primary),
                      onPressed: () async {
                        await widget.onEditCourse(c);
                        _loadCourses();
                      },
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 14, color: Colors.red),
                      onPressed: () async {
                        await widget.onDeleteCourse(c);
                        _loadCourses();
                      },
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    ),
                  ],
                ),
              )),
              // Add course
              InkWell(
                onTap: () async {
                  await widget.onAddCourse();
                  _loadCourses();
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 8, 16, 10),
                  child: Row(children: [
                    Icon(Icons.add, color: scheme.primary, size: 16),
                    const SizedBox(width: 6),
                    Text('Add Course',
                        style: TextStyle(
                            color: scheme.primary, fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.layers_outlined, size: 72, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text('No levels yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Tap + to add the first level',
            style: TextStyle(color: Colors.grey[500])),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add Level'),
        ),
      ]),
    );
  }
}
