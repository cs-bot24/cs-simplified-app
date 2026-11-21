// Study Groups: pick a PDF material (by search) to share into a chat.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/material_model.dart';

Future<MaterialModel?> pickMaterialToShare(BuildContext context) {
  return showModalBottomSheet<MaterialModel>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _PickerSheet(),
  );
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet();

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<MaterialModel> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;
  int _request = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(q));
  }

  Future<void> _search(String q) async {
    final term = q.trim();
    if (term.length < 2) {
      setState(() {
        _results = [];
        _searched = false;
        _error = null;
      });
      return;
    }
    final my = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ApiClient.search(term);
      if (!mounted || my != _request) return;
      final list = raw
          .map((e) => MaterialModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((m) => m.isPdf)
          .toList();
      setState(() {
        _results = list;
        _searched = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || my != _request) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Search failed. Try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: _onChanged,
                decoration: const InputDecoration(
                  hintText: 'Search a PDF to share (course code or title)',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (!_searched) {
      return Center(
        child: Text('Type at least 2 letters',
            style: TextStyle(color: Colors.grey[600])),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text('No PDF found', style: TextStyle(color: Colors.grey[600])),
      );
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final m = _results[i];
        return ListTile(
          leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
          title: Text(m.materialTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text([
            if (m.courseCode != null) m.courseCode!,
            if (m.categoryName != null) m.categoryName!,
          ].join('  ·  ')),
          onTap: () => Navigator.pop(context, m),
        );
      },
    );
  }
}
