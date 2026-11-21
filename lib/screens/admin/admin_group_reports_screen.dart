// Admin: review Study Group reports (remove a message, delete a group, resolve).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/study_group.dart';
import '../../services/study_groups_api.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';

class AdminGroupReportsScreen extends StatefulWidget {
  const AdminGroupReportsScreen({super.key});

  @override
  State<AdminGroupReportsScreen> createState() => _AdminGroupReportsScreenState();
}

class _AdminGroupReportsScreenState extends State<AdminGroupReportsScreen> {
  List<GroupReport>? _reports;
  String? _error;
  String _status = 'open';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await StudyGroupsApi.adminReports(status: _status);
      if (!mounted) return;
      setState(() {
        _reports = list;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = groupErrorMessage(e));
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<bool> _confirm(String title, String body, String yes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: Text(yes)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _resolve(GroupReport r) async {
    try {
      await StudyGroupsApi.adminResolveReport(r.id);
    } catch (e) {
      _snack(groupErrorMessage(e));
    }
    _load();
  }

  Future<void> _removeMessage(GroupReport r) async {
    if (!await _confirm('Remove this message?',
        'It disappears for everyone in the group.', 'Remove')) {
      return;
    }
    try {
      await StudyGroupsApi.adminDeleteMessage(r.messageId!);
      await StudyGroupsApi.adminResolveReport(r.id);
      _snack('Message removed');
    } catch (e) {
      _snack(groupErrorMessage(e));
    }
    _load();
  }

  Future<void> _deleteGroup(GroupReport r) async {
    if (!await _confirm('Delete "${r.groupName}"?',
        'The group and all its messages are deleted for everyone.', 'Delete group')) {
      return;
    }
    try {
      await StudyGroupsApi.adminDeleteGroup(r.groupId);
      _snack('Group deleted');
    } catch (e) {
      _snack(groupErrorMessage(e));
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Group Reports'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'open', label: Text('Open')),
                ButtonSegment(value: 'resolved', label: Text('Resolved')),
              ],
              selected: {_status},
              onSelectionChanged: (s) {
                setState(() {
                  _status = s.first;
                  _reports = null;
                });
                _load();
              },
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_reports == null && _error == null) return const LoadingView();
    if (_reports == null) return ErrorView(message: _error!, onRetry: _load);
    final reports = _reports!;
    if (reports.isEmpty) {
      return Center(
        child: Text(_status == 'open' ? 'No open reports 🎉' : 'Nothing resolved yet',
            style: TextStyle(color: Colors.grey[600])),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _card(reports[i]),
      ),
    );
  }

  Widget _card(GroupReport r) {
    final when = r.createdAt == null ? '' : DateFormat('d MMM, HH:mm').format(r.createdAt!);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.groupName,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              Chip(
                label: Text(r.reason),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Text('${r.memberCount} members · reported by ${r.reporterName} · $when',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 8),
          if (r.messageId == null)
            const Text('Report about the group itself',
                style: TextStyle(fontStyle: FontStyle.italic))
          else if (r.messageDeleted)
            const Text('(message already removed)',
                style: TextStyle(fontStyle: FontStyle.italic))
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${r.messageNickname ?? ''}: ${r.messageBody ?? ''}'),
            ),
          if (r.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Note: ${r.note}', style: const TextStyle(fontSize: 13)),
          ],
          if (_status == 'open') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (r.messageId != null && !r.messageDeleted)
                  OutlinedButton(
                      onPressed: () => _removeMessage(r), child: const Text('Remove message')),
                OutlinedButton(
                  onPressed: () => _deleteGroup(r),
                  child: const Text('Delete group', style: TextStyle(color: Colors.red)),
                ),
                FilledButton(onPressed: () => _resolve(r), child: const Text('Resolve')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
