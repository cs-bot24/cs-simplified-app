// Study Groups: the group chat (polling), PDF sharing, delete and report.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/study_group.dart';
import '../../services/study_groups_api.dart';
import '../pdf/pdf_viewer_screen.dart';
import 'group_info_screen.dart';
import 'group_widgets.dart';
import 'material_picker_sheet.dart';

class GroupChatScreen extends StatefulWidget {
  final int groupId;
  const GroupChatScreen({super.key, required this.groupId});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  StudyGroup? _group;
  List<GroupMessage> _messages = []; // oldest first
  bool _hasOlder = false;
  bool _loadingOlder = false;
  bool _loaded = false;
  String? _error;
  bool _sending = false;
  bool _reconnecting = false;

  Timer? _timer;
  bool _polling = false;
  bool _closed = false;
  int _failures = 0;
  int _tick = 0;
  DateTime _lastActivity = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _start();
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastActivity = DateTime.now();
      _poll();
    } else {
      _timer?.cancel();
    }
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  Future<void> _start() async {
    try {
      final g = await StudyGroupsApi.detail(widget.groupId);
      if (!g.isActive) {
        if (!mounted) return;
        setState(() => _error = 'You are not a member of this group.');
        return;
      }
      final page = await StudyGroupsApi.messages(widget.groupId);
      if (!mounted) return;
      setState(() {
        _group = g;
        _messages = page.messages;
        _hasOlder = page.hasOlder;
        _loaded = true;
        _error = null;
      });
      _scheduleNext();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = groupErrorMessage(e));
    }
  }

  int get _lastId => _messages.isEmpty ? 0 : _messages.last.id;

  Duration _interval() {
    final idle = DateTime.now().difference(_lastActivity);
    if (idle < const Duration(minutes: 1)) return const Duration(seconds: 3);
    if (idle < const Duration(minutes: 5)) return const Duration(seconds: 6);
    return const Duration(seconds: 12);
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (_closed) return;
    _timer = Timer(_interval(), _poll);
  }

  Future<void> _poll() async {
    if (_closed || _polling || !_loaded) return;
    _polling = true;
    try {
      _tick++;
      // Every 10th round re-read the latest page so deletions show up too.
      final full = _tick % 10 == 0;
      final page = await StudyGroupsApi.messages(widget.groupId,
          afterId: full ? 0 : _lastId);
      if (!mounted) return;
      _failures = 0;
      if (_reconnecting) setState(() => _reconnecting = false);
      _merge(page.messages, replaceExisting: full);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 403) {
        _closed = true;
        await _notifyRemoved();
        return;
      }
      _failures++;
      if (_failures >= 3 && !_reconnecting) setState(() => _reconnecting = true);
    } finally {
      _polling = false;
      if (mounted && !_closed) _scheduleNext();
    }
  }

  Future<void> _notifyRemoved() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No longer in this group'),
        content: const Text('You were removed from this group, or it was deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  void _merge(List<GroupMessage> incoming, {bool replaceExisting = false}) {
    if (incoming.isEmpty) return;
    final byId = {for (final m in _messages) m.id: m};
    var changed = false;
    var gotNew = false;
    for (final m in incoming) {
      final old = byId[m.id];
      if (old == null) {
        byId[m.id] = m;
        changed = true;
        gotNew = true;
      } else if (replaceExisting && old.deleted != m.deleted) {
        byId[m.id] = m;
        changed = true;
      }
    }
    if (!changed) return;
    if (gotNew) _lastActivity = DateTime.now();
    final list = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    setState(() => _messages = list);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    // The list is reversed: the "top" (older messages) is maxScrollExtent.
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 120) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasOlder || _messages.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final page =
          await StudyGroupsApi.messages(widget.groupId, beforeId: _messages.first.id);
      if (!mounted) return;
      final byId = {for (final m in _messages) m.id: m};
      for (final m in page.messages) {
        byId.putIfAbsent(m.id, () => m);
      }
      final list = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
      setState(() {
        _messages = list;
        _hasOlder = page.messages.isNotEmpty;
      });
    } catch (_) {
      // try again on the next scroll
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  // ── Sending ────────────────────────────────────────────────────────────────

  Future<void> _send({int? materialId}) async {
    final text = _input.text.trim();
    if (_sending || (text.isEmpty && materialId == null)) return;
    setState(() => _sending = true);
    try {
      final m = await StudyGroupsApi.sendMessage(widget.groupId,
          body: materialId == null ? text : '', materialId: materialId);
      if (!mounted) return;
      if (materialId == null) _input.clear();
      _lastActivity = DateTime.now();
      _merge([m]);
      _scheduleNext();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(groupErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach() async {
    final picked = await pickMaterialToShare(context);
    if (picked == null || !mounted) return;
    await _send(materialId: picked.id);
  }

  Future<void> _openMaterial(GroupMessage m) async {
    try {
      final j = await StudyGroupsApi.material(m.materialId!);
      if (!mounted) return;
      final url = (j['file_url'] ?? '') as String;
      final course = j['course'];
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            url: url,
            title: (j['material_title'] ?? m.materialTitle ?? 'Material') as String,
            materialId: m.materialId,
            courseCode: course is Map ? course['course_code'] as String? : null,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(m.materialTitle == null
              ? 'This material is no longer available.'
              : 'Could not open "${m.materialTitle}". It may have been removed.')));
    }
  }

  // ── Message actions ────────────────────────────────────────────────────────

  Future<void> _actions(GroupMessage m) async {
    if (m.deleted) return;
    final isAdmin = _group?.isAdmin ?? false;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.body.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy text'),
                onTap: () => Navigator.pop(ctx, 'copy'),
              ),
            if (!m.isMine)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report'),
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
            if (m.isMine || isAdmin)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: m.body));
        break;
      case 'delete':
        try {
          await StudyGroupsApi.deleteMessage(widget.groupId, m.id);
          if (!mounted) return;
          setState(() {
            _messages = [
              for (final x in _messages)
                if (x.id == m.id)
                  GroupMessage(
                    id: x.id,
                    nickname: x.nickname,
                    kind: x.kind,
                    body: '',
                    createdAt: x.createdAt,
                    deleted: true,
                    isMine: x.isMine,
                  )
                else
                  x
            ];
          });
        } catch (e) {
          _snack(groupErrorMessage(e));
        }
        break;
      case 'report':
        await _report(m);
        break;
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _report(GroupMessage m) async {
    const reasons = {
      'spam': 'Spam',
      'abuse': 'Abuse or bullying',
      'inappropriate': 'Inappropriate content',
      'other': 'Something else',
    };
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Report this message'),
        children: [
          for (final e in reasons.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, e.key),
              child: Text(e.value),
            ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    try {
      await StudyGroupsApi.report(widget.groupId, reason: reason, messageId: m.id);
      _snack('Thanks. The report was sent to the CS Simplified team.');
    } catch (e) {
      _snack(groupErrorMessage(e));
    }
  }

  Future<void> _openInfo() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => GroupInfoScreen(groupId: widget.groupId)),
    );
    if (!mounted) return;
    if (result == 'left') {
      Navigator.pop(context);
      return;
    }
    try {
      final g = await StudyGroupsApi.detail(widget.groupId);
      if (mounted) setState(() => _group = g);
    } catch (_) {}
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final g = _group;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: g == null ? null : _openInfo,
          child: Row(
            children: [
              if (g != null)
                GroupAvatar(id: g.id, name: g.name, icon: g.icon, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g?.name ?? 'Group',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    if (g != null)
                      Text('${g.memberCount} members · tap for info',
                          style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Group info',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: g == null ? null : _openInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_reconnecting)
            Container(
              width: double.infinity,
              color: Colors.orange,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Text('Reconnecting…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          Expanded(child: _messagesView()),
          if (_loaded) _composer(),
        ],
      ),
    );
  }

  Widget _messagesView() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() => _error = null);
                  _start();
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('No messages yet. Say hello 👋',
              style: TextStyle(color: Colors.grey[600])),
        ),
      );
    }
    final reversed = _messages.reversed.toList();
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: reversed.length + (_loadingOlder ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == reversed.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final m = reversed[i];
        // reversed list: the next index is the OLDER message
        final older = i + 1 < reversed.length ? reversed[i + 1] : null;
        final showDay = older == null || !_sameDay(older.createdAt, m.createdAt);
        return Column(
          children: [
            if (showDay) _DayLabel(date: m.createdAt),
            _Bubble(
              message: m,
              showName: !m.isMine && (older == null || older.nickname != m.nickname || showDay),
              onLongPress: () => _actions(m),
              onOpenMaterial: () => _openMaterial(m),
            ),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime? a, DateTime? b) =>
      a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.25))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Share a PDF',
              icon: const Icon(Icons.attach_file_rounded),
              onPressed: _sending ? null : _attach,
            ),
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 5,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Message',
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: _sending ? null : () => _send(),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  final DateTime? date;
  const _DayLabel({required this.date});

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final d = date!;
    String label;
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      label = 'Today';
    } else {
      final y = now.subtract(const Duration(days: 1));
      label = (d.year == y.year && d.month == y.month && d.day == y.day)
          ? 'Yesterday'
          : DateFormat('d MMM yyyy').format(d);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final GroupMessage message;
  final bool showName;
  final VoidCallback onLongPress;
  final VoidCallback onOpenMaterial;

  const _Bubble({
    required this.message,
    required this.showName,
    required this.onLongPress,
    required this.onOpenMaterial,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    final mine = m.isMine;
    final bg = mine ? const Color(0xFF1A3C6E) : Theme.of(context).cardColor;
    final fg = mine ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color;
    final time = m.createdAt == null ? '' : DateFormat('HH:mm').format(m.createdAt!);

    Widget content;
    if (m.deleted) {
      content = Text('This message was deleted',
          style: TextStyle(
              fontStyle: FontStyle.italic,
              color: mine ? Colors.white70 : Colors.grey[600],
              fontSize: 13));
    } else if (m.isMaterial) {
      content = InkWell(
        onTap: onOpenMaterial,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (mine ? Colors.white : Colors.red).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 28),
              const SizedBox(width: 8),
              Flexible(
                child: Text(m.materialTitle ?? 'Shared material',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: fg, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ],
          ),
        ),
      );
    } else {
      content = Text(m.body, style: TextStyle(color: fg, fontSize: 15));
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 4),
              bottomRight: Radius.circular(mine ? 4 : 14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showName)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(m.nickname,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: groupColor(m.nickname.hashCode))),
                ),
              content,
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerRight,
                child: Text(time,
                    style: TextStyle(
                        fontSize: 10, color: mine ? Colors.white60 : Colors.grey[600])),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
