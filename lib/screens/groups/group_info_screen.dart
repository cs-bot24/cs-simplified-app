// Study Groups: group details, join code, members, leave.
// Admins also get: join requests, remove member, make admin, edit, new code, delete.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/study_group.dart';
import '../../services/study_groups_api.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import 'group_chat_screen.dart';
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
  List<JoinRequest> _requests = const [];
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
      var requests = <JoinRequest>[];
      if (g.isAdmin) {
        try {
          requests = await StudyGroupsApi.requests(widget.groupId);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _group = g;
        _members = members;
        _requests = requests;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = groupErrorMessage(e));
    }
  }

  bool _muteBusy = false;

  Future<void> _toggleMute(bool muted) async {
    if (_muteBusy) return;
    final g = _group;
    if (g == null) return;
    setState(() => _muteBusy = true);
    try {
      final now = await StudyGroupsApi.setMute(widget.groupId, muted);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      _snack(now ? 'Notifications muted' : 'Notifications on');
    } catch (e) {
      if (!mounted) return;
      _snack(groupErrorMessage(e));
    } finally {
      if (mounted) setState(() => _muteBusy = false);
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
      Navigator.pop(context, 'left');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(groupErrorMessage(e))));
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  Future<void> _openChat() async {
    final r = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: widget.groupId)),
    );
    if (!mounted) return;
    if (r == 'left') {
      Navigator.pop(context, 'left');
      return;
    }
    _load();
  }

  Future<void> _answer(JoinRequest r, {required bool approve}) async {
    try {
      if (approve) {
        await StudyGroupsApi.approve(widget.groupId, r.id);
      } else {
        await StudyGroupsApi.decline(widget.groupId, r.id);
      }
      _snack(approve ? '${r.nickname} joined the group' : 'Request declined');
    } catch (e) {
      _snack(groupErrorMessage(e));
    }
    _load();
  }

  Future<void> _memberAction(GroupMember m, String action) async {
    if (action == 'remove') {
      if (!await _confirm('Remove ${m.nickname}?',
          'They will not be able to join this group again.', 'Remove')) {
        return;
      }
      try {
        await StudyGroupsApi.removeMember(widget.groupId, m.id);
      } catch (e) {
        _snack(groupErrorMessage(e));
      }
    } else if (action == 'admin') {
      if (!await _confirm('Make ${m.nickname} the admin?',
          'You will become a normal member.', 'Make admin')) {
        return;
      }
      try {
        await StudyGroupsApi.transferAdmin(widget.groupId, m.id);
      } catch (e) {
        _snack(groupErrorMessage(e));
      }
    }
    _load();
  }

  Future<void> _newCode() async {
    if (!await _confirm('Make a new code?',
        'The old code will stop working. People already in the group stay.', 'New code')) {
      return;
    }
    try {
      await StudyGroupsApi.regenerateCode(widget.groupId);
      _snack('New code created');
    } catch (e) {
      _snack(groupErrorMessage(e));
    }
    _load();
  }

  Future<void> _deleteGroup() async {
    if (!await _confirm('Delete this group?',
        'All messages are deleted for everyone. This cannot be undone.', 'Delete')) {
      return;
    }
    try {
      await StudyGroupsApi.deleteGroup(widget.groupId);
      if (!mounted) return;
      Navigator.pop(context, 'left');
    } catch (e) {
      _snack(groupErrorMessage(e));
    }
  }

  Future<void> _changeMyNickname() async {
    final nick = await askNickname(context,
        title: 'Change your nickname', confirmLabel: 'Save');
    if (nick == null || !mounted) return;
    try {
      await StudyGroupsApi.changeNickname(widget.groupId, nick);
      _snack('Nickname updated');
    } catch (e) {
      _snack(groupErrorMessage(e));
    }
    _load();
  }

  Future<void> _edit() async {
    final g = _group!;
    final name = TextEditingController(text: g.name);
    final desc = TextEditingController(text: g.description);
    var icon = g.icon;
    var privacy = g.privacy;
    var max = g.maxMembers.toDouble();
    final floor = g.memberCount < 2 ? 2 : g.memberCount;
    if (max < floor) max = floor.toDouble();
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit group'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                    controller: name,
                    maxLength: 25,
                    decoration: const InputDecoration(labelText: 'Group name')),
                TextField(
                    controller: desc,
                    maxLength: 150,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: kGroupIcons.keys
                      .map((k) => GestureDetector(
                            onTap: () => setState(() => icon = k),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: k == icon ? groupColor(g.id) : Colors.transparent,
                                    width: 2),
                              ),
                              child: GroupAvatar(id: g.id, name: name.text, icon: k, size: 36),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'public', label: Text('Public')),
                    ButtonSegment(value: 'private', label: Text('Private')),
                  ],
                  selected: {privacy},
                  onSelectionChanged: (s) => setState(() => privacy = s.first),
                ),
                const SizedBox(height: 8),
                Text('Maximum members: ${max.round()}'),
                Slider(
                  value: max,
                  min: 2,
                  max: 20,
                  divisions: 18,
                  label: '${max.round()}',
                  onChanged: (v) => setState(() => max = v < floor ? floor.toDouble() : v),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final n = name.text.trim();
                if (n.length < 3) {
                  setState(() => error = 'Name: 3 to 25 characters');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final newName = name.text.trim();
    final newDesc = desc.text.trim();
    name.dispose();
    desc.dispose();
    if (saved != true || !mounted) return;
    try {
      await StudyGroupsApi.update(
        g.id,
        name: newName,
        description: newDesc,
        icon: icon,
        privacy: privacy,
        maxMembers: max.round(),
        courseId: g.courseId,
      );
      _snack('Group updated');
    } catch (e) {
      _snack(groupErrorMessage(e));
    }
    _load();
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
          FilledButton.icon(
            onPressed: _openChat,
            icon: const Icon(Icons.chat_bubble_rounded),
            label: const Text('Open group chat'),
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
          if (g.isAdmin && _requests.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Join requests (${_requests.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ..._requests.map((r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.nickname),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Decline',
                        icon: const Icon(Icons.close_rounded, color: Colors.red),
                        onPressed: () => _answer(r, approve: false),
                      ),
                      IconButton(
                        tooltip: 'Approve',
                        icon: const Icon(Icons.check_rounded, color: Colors.green),
                        onPressed: () => _answer(r, approve: true),
                      ),
                    ],
                  ),
                )),
          ],
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
                    : (g.isAdmin && !m.isMe
                        ? PopupMenuButton<String>(
                            onSelected: (v) => _memberAction(m, v),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'admin', child: Text('Make admin')),
                              PopupMenuItem(value: 'remove', child: Text('Remove from group')),
                            ],
                          )
                        : null),
              )),
          const SizedBox(height: 20),
        ],
        if (g.isAdmin) ...[
          OutlinedButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Edit group'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _newCode,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Make a new invite code'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _deleteGroup,
            icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
            label: const Text('Delete group', style: TextStyle(color: Colors.red)),
          ),
          const SizedBox(height: 8),
        ],
        if (g.isActive) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_off_outlined),
            title: const Text('Mute notifications'),
            subtitle: const Text('No push alerts for new messages in this group'),
            value: g.myMuted,
            onChanged: _muteBusy ? null : _toggleMute,
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _changeMyNickname,
            icon: const Icon(Icons.badge_outlined),
            label: const Text('Change my nickname'),
          ),
          const SizedBox(height: 8),
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
