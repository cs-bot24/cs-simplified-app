import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      if (context.read<AuthProvider>().isLoggedIn)
        context.read<AcademicProvider>().fetchBookmarks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final a      = context.watch<AcademicProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Materials')),
      body: !auth.isLoggedIn
          ? Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_outline_rounded, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text('Sign in to save materials',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Bookmark your favourite study materials.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: const Text('Sign In'),
                ),
              ]),
            ))
          : a.loading ? const LoadingView()
          : a.bookmarks.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bookmark_outline_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text('No saved materials yet.'),
                  const SizedBox(height: 4),
                  Text('Bookmark materials while browsing.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: a.bookmarks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final mat = a.bookmarks[i];
                    return Card(
                      child: ListTile(
                        leading: Icon(Icons.picture_as_pdf_outlined, color: scheme.primary),
                        title: Text(mat.materialTitle,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        trailing: IconButton(
                          icon: const Icon(Icons.bookmark_remove_outlined, color: Colors.red),
                          onPressed: () => a.toggleBookmark(mat.id),
                        ),
                        onTap: () => Navigator.push(ctx, MaterialPageRoute(
                            builder: (_) => MaterialsScreen(
                                material: mat, courseCode: mat.courseCode ?? ''))),
                      ),
                    );
                  },
                ),
    );
  }
}
