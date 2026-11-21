// Study Groups: group details, join code, members, leave.
// (Chat and admin tools are added in the next step.)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/study_group.dart';
import '../../services/study_groups_api.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import 'group_widgets.dart';

class GroupInfoScreen extends StatefulWidget {
  final int groupId;
  const GroupInfoScreen({super.key, required this.groupId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  StudyGroup? _group;
  List<GroupMember> _members = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final g = await StudyGroupsApi.detail(widget.groupId);
      var members = <GroupMember>[];
      if (g.isActive) members = await StudyGroupsApi.members(widget.groupId);
      if (!mounted) return;
      setState(() {
        _group = g;
        _members = members;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = groupErrorMessage(e));
    }
  }

  Future<void> _leave() async {
    final g = _group!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this group?'),
        content: Text(g.isAdmin
            ? 'You are the admin. The longest-standing member becomes admin. '
                'If nobody else is in the group, it is deleted.'
            : 'You can join again later if there is room.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Leave')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await StudyGroupsApi.leave(g.id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(groupErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;
    return Scaffold(
      appBar: AppBar(title: Text(g?.name ?? 'Group')),
      body: g == null
          ? (_error == null
              ? const LoadingView()
              : ErrorView(message: _error!, onRetry: _load))
          : RefreshIndicator(onRefresh: _load, child: _content(g)),
    );
  }

  Widget _content(StudyGroup g) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(child: GroupAvatar(id: g.id, name: g.name, icon: g.icon, size: 72)),
        const SizedBox(height: 12),
        Text(g.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        if (g.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(g.description,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700])),
        ],
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            Chip(
                avatar: Icon(g.isPrivate ? Icons.lock_rounded : Icons.public_rounded, size: 16),
                label: Text(g.isPrivate ? 'Private' : 'Public')),
            Chip(
                avatar: const Icon(Icons.people_alt_rounded, size: 16),
                label: Text('${g.memberCount}/${g.maxMembers} members')),
            if (g.courseCode != null) Chip(label: Text(g.courseCode!)),
          ],
        ),
        if (g.isActive && g.joinCode != null) ...[
          const SizedBox(height: 16),
          _CodeCard(group: g),
        ],
        if (g.isActive) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded, color: Colors.blue),
                SizedBox(width: 10),
                Expanded(
                    child: Text('Group chat and PDF sharing are coming in the next update.',
                        style: TextStyle(fontSize: 13))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Members (${_members.length})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._members.map((m) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: groupColor(m.id).withOpacity(0.15),
                  child: Text(m.nickname.isEmpty ? '?' : m.nickname[0].toUpperCase(),
                      style: TextStyle(
                          color: groupColor(m.id), fontWeight: FontWeight.bold)),
                ),
                title: Text(m.isMe ? '${m.nickname} (you)' : m.nickname),
                trailing: m.isAdmin
                    ? const Chip(label: Text('Admin'), visualDensity: VisualDensity.compact)
                    : null,
              )),
          const SizedBox(height: 20),
        ],
        if (g.isActive || g.isPending)
          OutlinedButton.icon(
            onPressed: _leave,
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            label: Text(g.isPending ? 'Cancel request' : 'Leave group',
                style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}

class _CodeCard extends StatelessWidget {
  final StudyGroup group;
  const _CodeCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final code = group.joinCode!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(group.isPrivate ? 'Invite code' : 'Group code',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(code,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 6)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Code copied')));
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy'),
              ),
              TextButton.icon(
                onPressed: () => Share.share(
                    'Join my study group "${group.name}" on CS Simplified. '
                    'Open Study Groups, tap the key icon and enter code $code.'),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Share'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
