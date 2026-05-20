import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/academic_provider.dart';
import '../../widgets/loading_view.dart';
import '../browse/materials_screen.dart';
import '../auth/login_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});
  @override State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<AuthProvider>().isLoggedIn) {
        context.read<AcademicProvider>().fetchBookmarks();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final academic = context.watch<AcademicProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              color: const Color(AppConstants.primaryColorValue),
              child: const Text('Saved Materials',
                  style: TextStyle(color: Colors.white,
                      fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: !auth.isLoggedIn
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline_rounded,
                                size: 64,
                                color: Color(AppConstants.textLightValue)),
                            const SizedBox(height: 16),
                            const Text('Sign in to save materials',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Color(AppConstants.textDarkValue))),
                            const SizedBox(height: 8),
                            const Text(
                              'Create a free account to bookmark\nyour favourite study materials.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color(AppConstants.textLightValue)),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => Navigator.push(context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen())),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(
                                    AppConstants.primaryColorValue),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 14),
                              ),
                              child: const Text('Sign In',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : academic.loading
                      ? const LoadingView()
                      : academic.bookmarks.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bookmark_outline_rounded,
                                      size: 64,
                                      color:
                                          Color(AppConstants.textLightValue)),
                                  SizedBox(height: 12),
                                  Text('No saved materials yet.',
                                      style: TextStyle(
                                          color: Color(
                                              AppConstants.textLightValue))),
                                  SizedBox(height: 4),
                                  Text('Bookmark materials while browsing.',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Color(
                                              AppConstants.textLightValue))),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: academic.bookmarks.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final mat = academic.bookmarks[i];
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
                                  tileColor: const Color(
                                      AppConstants.accentColorValue),
                                  leading: const Icon(
                                      Icons.picture_as_pdf_outlined,
                                      color: Color(
                                          AppConstants.primaryColorValue)),
                                  title: Text(mat.materialTitle,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                  trailing: IconButton(
                                    icon: const Icon(
                                        Icons.bookmark_remove_outlined,
                                        color: Color(
                                            AppConstants.errorColorValue)),
                                    onPressed: () =>
                                        academic.toggleBookmark(mat.id),
                                  ),
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
