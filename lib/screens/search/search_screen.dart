import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/academic_provider.dart';
import '../../providers/offline_provider.dart';
import '../../core/connectivity_service.dart';
import '../../models/material_model.dart';
import '../../models/offline_material.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/requires_internet_view.dart';
import '../browse/materials_screen.dart';
import '../pdf/pdf_viewer_screen.dart';

class SearchScreen extends StatefulWidget {
  /// Optional pre-filled search query.
  /// When provided (e.g. from ExamPrepBanner), the screen auto-searches
  /// on load so the user sees results immediately without having to type.
  final String initialQuery;

  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  bool _searched = false;

  /// Non-null while offline — results come from the local Offline Library
  /// instead of the server. Cleared on the next search once back online.
  List<OfflineMaterial>? _offlineResults;

  @override
  void initState() {
    super.initState();
    // If an initial query was provided, pre-fill and auto-search
    if (widget.initialQuery.isNotEmpty) {
      _ctrl.text = widget.initialQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _search(widget.initialQuery);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) return;
    setState(() => _searched = true);

    if (ConnectivityService.instance.isOffline) {
      // No internet — search what's already downloaded instead of just
      // failing. Not a replacement for full search, but real materials
      // the student already has are genuinely findable offline.
      final offline = context.read<OfflineProvider>();
      final downloaded = offline.materials.where((m) => m.isDownloaded).toList();
      setState(() => _offlineResults = offline.search(q.trim())
          .where(downloaded.contains)
          .toList());
      return;
    }

    setState(() => _offlineResults = null);
    await context.read<AcademicProvider>().search(q.trim());
  }

  @override
  Widget build(BuildContext context) {
    final a      = context.watch<AcademicProvider>();
    final scheme = Theme.of(context).colorScheme;
    final offlineMode = _offlineResults != null;

    return Scaffold(
      body: SafeArea(child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          color: scheme.primary,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Search', style: TextStyle(color: Colors.white,
                fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              onSubmitted: _search,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search courses, topics, materials…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _ctrl.clear();
                          context.read<AcademicProvider>().clearSearch();
                          setState(() { _searched = false; _offlineResults = null; });
                        })
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ]),
        ),

        if (offlineMode)
          const RequiresInternetInlineBanner(
              message: 'Offline — searching your downloaded materials only.'),

        // Results
        Expanded(
          child: offlineMode
              ? _buildOfflineResults()
              : a.loading
                  ? const LoadingView()
                  : !_searched
                      ? _buildPrompt()
                      : (a.searchResults.isEmpty && a.error != null)
                          ? RequiresInternetView(
                              featureName: 'Search',
                              onRetry: () => _search(_ctrl.text),
                            )
                          : a.searchResults.isEmpty
                              ? _buildNoResults()
                              : _buildServerResults(a.searchResults, scheme),
        ),
      ])),
    );
  }

  Widget _buildPrompt() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_rounded, size: 72, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text('Search for materials',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Type a keyword and press Enter', style: TextStyle(color: Colors.grey[500])),
        ]),
      );

  Widget _buildNoResults() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('No results for "${_ctrl.text}"', style: TextStyle(color: Colors.grey[500])),
        ]),
      );

  Widget _buildOfflineResults() {
    final results = _offlineResults!;
    if (results.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('No downloaded materials match "${_ctrl.text}"',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final m = results[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.offline_pin_rounded, color: Colors.green),
            title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(m.courseCode ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => PdfViewerScreen(
                url: m.fileUrl, title: m.title, materialId: m.materialId,
                courseCode: m.courseCode, categoryName: m.categoryName,
              ),
            )),
          ),
        );
      },
    );
  }

  Widget _buildServerResults(List<MaterialModel> results, ColorScheme scheme) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final mat = results[i];
        return Card(
          child: ListTile(
            leading: Icon(Icons.picture_as_pdf_outlined, color: scheme.primary),
            title: Text(mat.materialTitle,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              '${mat.courseCode ?? ''}${mat.levelName != null ? ' • ${mat.levelName}' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => MaterialsScreen(
                  material: mat, courseCode: mat.courseCode ?? ''),
              ),
            ),
          ),
        );
      },
    );
  }
}
