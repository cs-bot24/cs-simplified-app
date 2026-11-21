// Study Groups: main screen with "My Groups" and "Discover" tabs.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/study_group.dart';
import '../../services/study_groups_api.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';
import 'group_widgets.dart';

class StudyGroupsScreen extends StatefulWidget {
  const StudyGroupsScreen({super.key});

  @override
  State<StudyGroupsScreen> createState() => _StudyGroupsScreenState();
}

class _StudyGroupsScreenState extends State<StudyGroupsScreen> {
  final _mineKey = GlobalKey<_MyGroupsTabState>();
  final _discoverKey = GlobalKey<_DiscoverTabState>();

  void _reloadBoth() {
    _mineKey.currentState?.reload();
    _discoverKey.currentState?.reload();
  }

  Future<void> _openGroup(StudyGroup g) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: g.id)));
    if (mounted) _reloadBoth();
  }

  Future<void> _create() async {
    final created = await Navigator.push<StudyGroup>(
        context, MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
    if (!mounted) return;
    _reloadBoth();
    if (created != null) _openGroup(created);
  }

  Future<void> _joinWithCode() async {
    final codeCtrl = TextEditingController();
    final nickCtrl = TextEditingController();
    final hint = await StudyGroupsApi.nicknameHint();
    nickCtrl.text = hint;
    if (!mounted) return;
    String? error;
    bool busy = false;
    final joined = await showDialog<StudyGroup>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Join with a code'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: '6-digit group code'),
                ),
                TextField(
                  controller: nickCtrl,
                  maxLength: 20,
                  decoration: const InputDecoration(
                      labelText: 'Your nickname in this group'),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final code = codeCtrl.text.trim();
                      final nick = nickCtrl.text.trim();
                      if (code.length != 6) {
                        setState(() => error = 'The code is 6 digits.');
                        return;
                      }
                      if (nick.length < 2) {
                        setState(() => error = 'Nickname: at least 2 characters.');
                        return;
                      }
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        final g = await StudyGroupsApi.joinByCode(code, nick);
                        if (ctx.mounted) Navigator.pop(ctx, g);
                      } catch (e) {
                        if (ctx.mounted) {
                          setState(() {
                            busy = false;
                            error = groupErrorMessage(e);
                          });
                        }
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Join'),
            ),
          ],
        ),
      ),
    );
    codeCtrl.dispose();
    nickCtrl.dispose();
    if (joined == null || !mounted) return;
    _reloadBoth();
    if (joined.isPending) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Request sent. The group admin will approve you.')));
    } else {
      _openGroup(joined);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Study Groups'),
          actions: [
            IconButton(
              tooltip: 'Join with a code',
              icon: const Icon(Icons.vpn_key_rounded),
              onPressed: _joinWithCode,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [Tab(text: 'My Groups'), Tab(text: 'Discover')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _create,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create'),
        ),
        body: TabBarView(
          children: [
            _MyGroupsTab(key: _mineKey, onOpen: _openGroup, onCreate: _create),
            _DiscoverTab(key: _discoverKey, onOpen: _openGroup, onChanged: _reloadBoth),
          ],
        ),
      ),
    );
  }
}

// ── My Groups ────────────────────────────────────────────────────────────────

class _MyGroupsTab extends StatefulWidget {
  final void Function(StudyGroup) onOpen;
  final VoidCallback onCreate;
  const _MyGroupsTab({super.key, required this.onOpen, required this.onCreate});

  @override
  State<_MyGroupsTab> createState() => _MyGroupsTabState();
}

class _MyGroupsTabState extends State<_MyGroupsTab>
    with AutomaticKeepAliveClientMixin {
  List<StudyGroup>? _groups;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final list = await StudyGroupsApi.myGroups();
      if (!mounted) return;
      setState(() {
        _groups = list;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = groupErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_groups == null && _error == null) return const LoadingView();
    if (_groups == null) return ErrorView(message: _error!, onRetry: reload);
    final groups = _groups!;
    if (groups.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.groups_rounded, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No study groups yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Create a group for your course or find one in Discover. '
            'Study together, share materials, stay motivated.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: widget.onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create a group'),
            ),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _MyGroupTile(group: groups[i], onTap: () {
          final g = groups[i];
          if (g.isPending) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Waiting for the admin to approve your request.')));
          } else {
            widget.onOpen(g);
          }
        }),
      ),
    );
  }
}

class _MyGroupTile extends StatelessWidget {
  final StudyGroup group;
  final VoidCallback onTap;
  const _MyGroupTile({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final g = group;
    String subtitle;
    if (g.isPending) {
      subtitle = 'Request pending';
    } else if (g.lastMessageText != null) {
      subtitle = '${g.lastMessageNickname ?? ''}: ${g.lastMessageText}';
    } else {
      subtitle = '${g.memberCount}/${g.maxMembers} members';
    }
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              GroupAvatar(id: g.id, name: g.name, icon: g.icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(g.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                        if (g.isPrivate)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.lock_rounded, size: 14, color: Colors.grey),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ),
              if (g.unreadCount > 0)
                _Badge(text: g.unreadCount > 99 ? '99+' : '${g.unreadCount}')
              else if (g.pendingCount > 0)
                _Badge(text: '${g.pendingCount} req', color: Colors.orange),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, this.color = const Color(0xFF1A3C6E)});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      );
}

// ── Discover ─────────────────────────────────────────────────────────────────

class _DiscoverTab extends StatefulWidget {
  final void Function(StudyGroup) onOpen;
  final VoidCallback onChanged;
  const _DiscoverTab({super.key, required this.onOpen, required this.onChanged});

  @override
  State<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<_DiscoverTab>
    with AutomaticKeepAliveClientMixin {
  static const _page = 20;
  final _search = TextEditingController();
  Timer? _debounce;
  List<StudyGroup>? _groups;
  String? _error;
  bool _more = false;
  bool _loadingMore = false;
  int _request = 0; // ignore out-of-date responses

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    final my = ++_request;
    try {
      final list = await StudyGroupsApi.discover(query: _search.text, limit: _page);
      if (!mounted || my != _request) return;
      setState(() {
        _groups = list;
        _more = list.length == _page;
        _error = null;
      });
    } catch (e) {
      if (!mounted || my != _request) return;
      setState(() => _error = groupErrorMessage(e));
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _groups == null) return;
    setState(() => _loadingMore = true);
    final my = _request;
    try {
      final list = await StudyGroupsApi.discover(
          query: _search.text, offset: _groups!.length, limit: _page);
      if (!mounted || my != _request) return;
      setState(() {
        _groups = [..._groups!, ...list];
        _more = list.length == _page;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(groupErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), reload);
  }

  Future<void> _join(StudyGroup g) async {
    final nick = await askNickname(context, title: 'Join "${g.name}"');
    if (nick == null || !mounted) return;
    try {
      final joined = await StudyGroupsApi.join(g.id, nick);
      if (!mounted) return;
      widget.onChanged();
      widget.onOpen(joined);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(groupErrorMessage(e))));
      reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _search,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search public groups',
              prefixIcon: Icon(Icons.search_rounded),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_groups == null && _error == null) return const LoadingView();
    if (_groups == null) return ErrorView(message: _error!, onRetry: reload);
    final groups = _groups!;
    if (groups.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 48),
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            _search.text.trim().isEmpty
                ? 'No public groups yet. Be the first to create one!'
                : 'No group matches your search.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: groups.length + (_more ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          if (i == groups.length) {
            return Center(
              child: _loadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(onPressed: _loadMore, child: const Text('Load more')),
            );
          }
          return _DiscoverTile(
              group: groups[i], onJoin: () => _join(groups[i]), onOpen: () => widget.onOpen(groups[i]));
        },
      ),
    );
  }
}

class _DiscoverTile extends StatelessWidget {
  final StudyGroup group;
  final VoidCallback onJoin;
  final VoidCallback onOpen;
  const _DiscoverTile(
      {required this.group, required this.onJoin, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final g = group;
    Widget action;
    if (g.isActive) {
      action = OutlinedButton(onPressed: onOpen, child: const Text('Open'));
    } else if (g.isPending) {
      action = const Chip(label: Text('Pending'));
    } else if (g.isFull) {
      action = const Chip(label: Text('Full'));
    } else {
      action = FilledButton(onPressed: onJoin, child: const Text('Join'));
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          GroupAvatar(id: g.id, name: g.name, icon: g.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                if (g.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(g.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${g.memberCount}/${g.maxMembers} members'
                  '${g.courseCode != null ? '  ·  ${g.courseCode}' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          action,
        ],
      ),
    );
  }
}
