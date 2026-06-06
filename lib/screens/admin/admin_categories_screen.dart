import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../models/category_model.dart';

/// Admin panel: create, edit, delete, reorder categories.
/// Changes appear instantly throughout the app on next fetch.
class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});
  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  List<CategoryModel> _categories = [];
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.getCategories();
      setState(() {
        _categories = data.map((e) => CategoryModel.fromJson(e)).toList();
        _loading    = false;
      });
    } catch (e) {
      setState(() { _error = 'Could not load categories.'; _loading = false; });
    }
  }

  Future<void> _showForm({CategoryModel? existing}) async {
    final nameCtrl  = TextEditingController(text: existing?.categoryName ?? '');
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '📄');
    String? err;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          title: Text(existing == null ? 'New Category' : 'Edit Category'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(err!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            TextField(
              controller: emojiCtrl,
              decoration: const InputDecoration(
                labelText: 'Emoji',
                hintText:  '📄',
                border:    OutlineInputBorder(),
              ),
              maxLength: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller:   nameCtrl,
              autofocus:    true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText:  'e.g. Lab Materials',
                border:    OutlineInputBorder(),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:     const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name  = nameCtrl.text.trim();
                final emoji = emojiCtrl.text.trim();
                if (name.isEmpty) {
                  setLocal(() => err = 'Category name is required.');
                  return;
                }
                Navigator.pop(ctx);
                try {
                  if (existing == null) {
                    await ApiClient.createCategory(
                        name: name, emoji: emoji.isEmpty ? '📄' : emoji);
                  } else {
                    await ApiClient.updateCategory(
                        id: existing.id,
                        name: name,
                        emoji: emoji.isEmpty ? '📄' : emoji);
                  }
                  await _fetch();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(existing == null
                          ? 'Category created.' : 'Category updated.'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                }
              },
              child: Text(existing == null ? 'Create' : 'Save'),
            ),
          ],
        );
      }),
    );

    nameCtrl.dispose();
    emojiCtrl.dispose();
  }

  Future<void> _delete(CategoryModel cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Delete "${cat.categoryName}"?\n\n'
          'This will fail if any materials are assigned to it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:     const Text('Cancel'),
          ),
          TextButton(
            style:     TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child:     const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ApiClient.deleteCategory(cat.id);
      await _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:         Text('Category deleted.'),
          backgroundColor: Colors.green,
          behavior:        SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text(e.toString()),
          backgroundColor: Colors.red,
          behavior:        SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        actions: [
          IconButton(
            icon:     const Icon(Icons.refresh_rounded),
            onPressed: _fetch,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon:      const Icon(Icons.add_rounded),
        label:     const Text('New Category'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(_error!),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _fetch, child: const Text('Retry')),
                ]))
              : _categories.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('📂', style: TextStyle(fontSize: 52)),
                      const SizedBox(height: 12),
                      const Text('No categories yet.',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Tap + to create one.',
                          style: TextStyle(color: Colors.grey[500])),
                    ]))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount:       _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder:     (ctx, i) {
                        final cat = _categories[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: scheme.primary.withOpacity(0.12)),
                          ),
                          child: Row(children: [
                            Text(cat.emoji,
                                style: const TextStyle(fontSize: 26)),
                            const SizedBox(width: 14),
                            Expanded(child: Text(cat.categoryName,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600))),
                            IconButton(
                              icon:      const Icon(Icons.edit_outlined,
                                  size: 20),
                              onPressed: () => _showForm(existing: cat),
                              tooltip:   'Edit',
                            ),
                            IconButton(
                              icon:      const Icon(Icons.delete_outline,
                                  size: 20, color: Colors.red),
                              onPressed: () => _delete(cat),
                              tooltip:   'Delete',
                            ),
                          ]),
                        );
                      },
                    ),
    );
  }
}
