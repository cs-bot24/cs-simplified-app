import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/academic_provider.dart';
import '../../widgets/loading_view.dart';
import '../browse/materials_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  bool _hasSearched = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) return;
    setState(() => _hasSearched = true);
    await context.read<AcademicProvider>().search(q.trim());
  }

  @override
  Widget build(BuildContext context) {
    final academic = context.watch<AcademicProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              color: const Color(AppConstants.primaryColorValue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Search',
                      style: TextStyle(color: Colors.white,
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _ctrl,
                    onSubmitted: _search,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search courses, topics, materials…',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _ctrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _ctrl.clear();
                                context.read<AcademicProvider>().clearSearch();
                                setState(() => _hasSearched = false);
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),

            // Results
            Expanded(
              child: academic.loading
                  ? const LoadingView()
                  : !_hasSearched
                      ? _EmptySearch()
                      : academic.searchResults.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.search_off_rounded,
                                      size: 64,
                                      color: Color(AppConstants.textLightValue)),
                                  const SizedBox(height: 12),
                                  Text('No results for "${_ctrl.text}"',
                                      style: const TextStyle(
                                          color: Color(
                                              AppConstants.textLightValue))),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: academic.searchResults.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final mat = academic.searchResults[i];
                                return ListTile(
                                  onTap: () => Navigator.push(context,
                                      MaterialPageRoute(
                                          builder: (_) => MaterialsScreen(
                                              material: mat,
                                              courseCode:
                                                  mat.courseCode ?? ''))),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                  tileColor:
                                      const Color(AppConstants.accentColorValue),
                                  leading: Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(AppConstants
                                              .primaryColorValue)
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                        Icons.picture_as_pdf_outlined,
                                        color: Color(AppConstants
                                            .primaryColorValue),
                                        size: 20),
                                  ),
                                  title: Text(mat.materialTitle,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Color(AppConstants
                                              .textDarkValue))),
                                  subtitle: Text(
                                    '${mat.courseCode ?? ''}'
                                    '${mat.levelName != null ? ' • ${mat.levelName}' : ''}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(
                                            AppConstants.textLightValue)),
                                  ),
                                  trailing: const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color:
                                          Color(AppConstants.textLightValue)),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded,
                size: 72, color: Color(AppConstants.accentColorValue)),
            SizedBox(height: 16),
            Text('Search for materials',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600,
                    color: Color(AppConstants.textDarkValue))),
            SizedBox(height: 8),
            Text(
              'Type a course code or topic\nand press Enter',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(AppConstants.textLightValue)),
            ),
          ],
        ),
      ),
    );
  }
}
