import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../core/storage.dart';
import '../../core/constants.dart';
import '../../core/api_client.dart';
import '../../models/level_model.dart';
import '../../models/semester_model.dart';
import '../../models/course_model.dart';
import '../../models/category_model.dart';

class UploadMaterialScreen extends StatefulWidget {
  const UploadMaterialScreen({super.key});
  @override State<UploadMaterialScreen> createState() =>
      _UploadMaterialScreenState();
}

class _UploadMaterialScreenState extends State<UploadMaterialScreen> {
  // Selection state
  LevelModel?    _level;
  SemesterModel? _semester;
  CourseModel?   _course;
  CategoryModel? _category;

  List<LevelModel>    _levels     = [];
  List<SemesterModel> _semesters  = [];
  List<CourseModel>   _courses    = [];
  List<CategoryModel> _categories = [];

  PlatformFile? _pickedFile;
  final _titleCtrl = TextEditingController();
  bool _uploading  = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _loadLevels();
    _loadCategories();
  }

  @override
  void dispose() { _titleCtrl.dispose(); super.dispose(); }

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
        _semester = null; _course = null; _courses = [];
      });
    } catch (_) {}
  }

  Future<void> _loadCourses(int semesterId) async {
    try {
      final data = await ApiClient.getCourses(semesterId);
      setState(() {
        _courses = data.map((e) => CourseModel.fromJson(e)).toList();
        _course = null;
      });
    } catch (_) {}
  }

  Future<void> _loadCategories() async {
    try {
      final data = await ApiClient.getCategories();
      setState(() => _categories = data.map((e) => CategoryModel.fromJson(e)).toList());
    } catch (_) {}
  }


  MediaType _contentType(String ext) {
    switch (ext) {
      case 'ppt':  return MediaType('application', 'vnd.ms-powerpoint');
      case 'pptx': return MediaType('application',
          'vnd.openxmlformats-officedocument.presentationml.presentation');
      case 'doc':  return MediaType('application', 'msword');
      case 'docx': return MediaType('application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document');
      default:     return MediaType('application', 'pdf');
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf', 'ppt', 'pptx', 'doc', 'docx'],
    );
    if (result != null) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Future<void> _upload() async {
    if (_course == null || _category == null ||
        _pickedFile == null || _titleCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill all fields and select a file.');
      return;
    }
    setState(() { _uploading = true; _error = null; _success = null; });
    try {
      final token = AppStorage.getToken();
      final uri = Uri.parse('${AppConstants.baseUrl}/materials');
      final req  = http.MultipartRequest('POST', uri);
      req.headers['Authorization'] = 'Bearer $token';
      req.fields['course_id']       = '${_course!.id}';
      req.fields['category_id']     = '${_category!.id}';
      req.fields['material_title']  = _titleCtrl.text.trim();

      final ext  = _pickedFile!.name.split('.').last.toLowerCase();
      final ctype = _contentType(ext);
      if (_pickedFile!.path != null) {
        req.files.add(await http.MultipartFile.fromPath(
          'file', _pickedFile!.path!,
          contentType: ctype,
        ));
      } else if (_pickedFile!.bytes != null) {
        req.files.add(http.MultipartFile.fromBytes(
          'file', _pickedFile!.bytes!,
          filename: _pickedFile!.name,
          contentType: ctype,
        ));
      }

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 201) {
        setState(() {
          _success = 'Material uploaded successfully!';
          _pickedFile = null; _titleCtrl.clear();
          _level = null; _semester = null; _course = null; _category = null;
          _semesters = []; _courses = [];
        });
      } else {
        setState(() => _error = 'Upload failed (${res.statusCode}). Check your connection.');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Material')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step indicator
            _StepHeader(step: '1', title: 'Select Location'),
            const SizedBox(height: 12),

            // Level dropdown
            _DropdownCard<LevelModel>(
              label: 'Level',
              value: _level,
              items: _levels,
              itemLabel: (l) => '${l.emoji} ${l.levelName}',
              onChanged: (l) {
                setState(() { _level = l; _semester = null; _course = null; });
                if (l != null) _loadSemesters(l.id);
              },
            ),
            const SizedBox(height: 10),

            // Semester dropdown
            if (_semesters.isNotEmpty)
              _DropdownCard<SemesterModel>(
                label: 'Semester',
                value: _semester,
                items: _semesters,
                itemLabel: (s) => s.semesterName,
                onChanged: (s) {
                  setState(() { _semester = s; _course = null; });
                  if (s != null) _loadCourses(s.id);
                },
              ),
            if (_semesters.isNotEmpty) const SizedBox(height: 10),

            // Course dropdown
            if (_courses.isNotEmpty)
              _DropdownCard<CourseModel>(
                label: 'Course',
                value: _course,
                items: _courses,
                itemLabel: (c) => '${c.courseCode} — ${c.courseTitle}',
                onChanged: (c) => setState(() => _course = c),
              ),
            if (_courses.isNotEmpty) const SizedBox(height: 10),

            // Category dropdown
            _DropdownCard<CategoryModel>(
              label: 'Category',
              value: _category,
              items: _categories,
              itemLabel: (c) => '${c.emoji} ${c.categoryName}',
              onChanged: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 24),

            _StepHeader(step: '2', title: 'Material Details'),
            const SizedBox(height: 12),

            // Title field
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Display Title',
                hintText: 'e.g. COSC 211 - Java OOP Explained',
                prefixIcon: const Icon(Icons.title_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                filled: true,
              ),
            ),
            const SizedBox(height: 24),

            _StepHeader(step: '3', title: 'Select File (PDF, PPTX, DOCX)'),
            const SizedBox(height: 12),

            // File picker
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _pickedFile != null
                      ? Colors.green.withOpacity(0.1)
                      : scheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _pickedFile != null
                        ? Colors.green
                        : scheme.primary.withOpacity(0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(children: [
                  Icon(
                    _pickedFile != null
                        ? Icons.check_circle_rounded
                        : Icons.upload_file_rounded,
                    size: 48,
                    color: _pickedFile != null ? Colors.green : scheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _pickedFile != null
                        ? _pickedFile!.name
                        : 'Tap to select file',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _pickedFile != null ? Colors.green : scheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_pickedFile != null)
                    Text(
                      '${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 24),

            // Error / success
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13))),
                ]),
              ),
            if (_success != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text(_success!, style: const TextStyle(color: Colors.green, fontSize: 13)),
                ]),
              ),
            if (_error != null || _success != null) const SizedBox(height: 16),

            // Upload button
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : _upload,
                icon: _uploading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                label: Text(_uploading ? 'Uploading...' : 'Upload Material',
                    style: const TextStyle(color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String step, title;
  const _StepHeader({required this.step, required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
        child: Center(child: Text(step,
            style: const TextStyle(color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.bold))),
      ),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ]);
  }
}

class _DropdownCard<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _DropdownCard({required this.label, required this.value,
      required this.items, required this.itemLabel, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text('Select $label'),
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
