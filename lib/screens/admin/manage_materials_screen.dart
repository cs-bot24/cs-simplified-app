import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../models/level_model.dart';
import '../../models/semester_model.dart';
import '../../models/course_model.dart';
import '../../models/material_model.dart';

class ManageMaterialsScreen extends StatefulWidget {
  const ManageMaterialsScreen({super.key});
  @override State<ManageMaterialsScreen> createState() => _ManageMaterialsScreenState();
}

class _ManageMaterialsScreenState extends State<ManageMaterialsScreen> {
  List<LevelModel>    _levels    = [];
  List<SemesterModel> _semesters = [];
  List<CourseModel>   _courses   = [];
  List<MaterialModel> _materials = [];

  LevelModel?    _level;
  SemesterModel? _semester;
  CourseModel?   _course;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    try {
      final data = await ApiClient.getLevels();
      setState(() => _levels = data.map((e) => LevelModel.fromJson(e)).toList());
    } catch (_) {}
  }

  Future<void> _loadSemesters(int levelId) async {
    try {
      final data = await ApiClient.getSemesters(levelId);
      setState(() {
        _semesters = data.map((e) => SemesterModel.fromJson(e)).toList();
        _semester = null; _course = null; _courses = []; _materials = [];
      });
    } catch (_) {}
  }

  Future<void> _loadCourses(int semId) async {
    try {
      final data = await ApiClient.getCourses(semId);
      setState(() {
        _courses = data.map((e) => CourseModel.fromJson(e)).toList();
        _course = null; _materials = [];
      });
    } catch (_) {}
  }

  Future<void> _loadMaterials(int courseId) async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.getMaterials(courseId);
      setState(() => _materials = data.map((e) => MaterialModel.fromJson(e)).toList());
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _editTitle(MaterialModel mat) async {
    final ctrl = TextEditingController(text: mat.materialTitle);
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Title'),
        content: TextField(controller: ctrl,
            decoration: const InputDecoration(labelText: 'New Title')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (result == true && ctrl.text.isNotEmpty && _course != null) {
      try {
        await ApiClient.updateMaterialTitle(mat.id, ctrl.text.trim());
        await _loadMaterials(_course!.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title updated')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteMaterial(MaterialModel mat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Material'),
        content: Text('Hide "${mat.materialTitle}" from students?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && _course != null) {
      try {
        await ApiClient.deleteMaterial(mat.id);
        await _loadMaterials(_course!.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Material hidden from students')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Materials')),
      body: Column(
        children: [
          // Filter section
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Column(children: [
              _buildDropdown<LevelModel>(
                label: 'Select Level',
                value: _level,
                items: _levels,
                itemLabel: (l) => '${l.emoji} ${l.levelName}',
                onChanged: (l) {
                  setState(() { _level = l; _semester = null; _course = null; });
                  if (l != null) _loadSemesters(l.id);
                },
              ),
              if (_semesters.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildDropdown<SemesterModel>(
                  label: 'Select Semester',
                  value: _semester,
                  items: _semesters,
                  itemLabel: (s) => s.semesterName,
                  onChanged: (s) {
                    setState(() { _semester = s; _course = null; });
                    if (s != null) _loadCourses(s.id);
                  },
                ),
              ],
              if (_courses.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildDropdown<CourseModel>(
                  label: 'Select Course',
                  value: _course,
                  items: _courses,
                  itemLabel: (c) => c.courseCode,
                  onChanged: (c) {
                    setState(() => _course = c);
                    if (c != null) _loadMaterials(c.id);
                  },
                ),
              ],
            ]),
          ),

          // Materials list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _course == null
                    ? Center(child: Text('Select a course to view materials',
                        style: TextStyle(color: Colors.grey[500])))
                    : _materials.isEmpty
                        ? Center(child: Text('No materials for ${_course!.courseCode}',
                            style: TextStyle(color: Colors.grey[500])))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _materials.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final mat = _materials[i];
                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.picture_as_pdf_outlined,
                                      color: Colors.orange),
                                  title: Text(mat.materialTitle,
                                      style: const TextStyle(fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                  subtitle: Text(mat.uploadedAt.split('T').first,
                                      style: const TextStyle(fontSize: 11)),
                                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          color: Colors.blue, size: 20),
                                      onPressed: () => _editTitle(mat),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red, size: 20),
                                      onPressed: () => _deleteMaterial(mat),
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label, required T? value, required List<T> items,
    required String Function(T) itemLabel, required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true, value: value, hint: Text(label),
          items: items.map((item) => DropdownMenuItem<T>(
            value: item,
            child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
