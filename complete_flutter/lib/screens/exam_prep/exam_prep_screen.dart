import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../models/material_model.dart';
import '../../screens/pdf/pdf_viewer_screen.dart';

/// Dedicated screen for Exam Preparation materials.
///
/// Fetches all materials whose category name contains "exam" directly
/// from the backend. This is a category lookup — not a search query —
/// so it works regardless of what words appear in material titles.
///
/// The admin just needs to have a category named "Exam Preparation"
/// (or any name containing "exam") and upload materials into it.
class ExamPrepScreen extends StatefulWidget {
  const ExamPrepScreen({super.key});

  @override
  State<ExamPrepScreen> createState() => _ExamPrepScreenState();
}

class _ExamPrepScreenState extends State<ExamPrepScreen> {
  List<MaterialModel> _materials = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMaterials();
  }

  Future<void> _fetchMaterials() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await ApiClient.getExamPrepMaterials();
      setState(() {
        _materials = (raw as List)
            .map((e) => MaterialModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Could not load materials.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFB45309), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                const Text('🧠', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                const Text(
                  'Exam Preparation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _loading
                      ? 'Loading resources…'
                      : _materials.isEmpty
                          ? 'No resources yet'
                          : '${_materials.length} resource${_materials.length == 1 ? '' : 's'} available',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _error != null
                    ? _buildError()
                    : _materials.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _fetchMaterials,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(20),
                              itemCount: _materials.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (ctx, i) =>
                                  _MaterialTile(material: _materials[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchMaterials,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧠', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'No Exam Prep materials yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The admin will upload exam preparation\nmaterials here soon.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Individual material tile ───────────────────────────────────────────────

class _MaterialTile extends StatelessWidget {
  final MaterialModel material;
  const _MaterialTile({required this.material});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            url: material.fileUrl,
            title: material.materialTitle,
            materialId: material.id,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFD97706).withOpacity(0.20),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Color(0xFFD97706),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.materialTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (material.courseCode != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      material.courseCode!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
