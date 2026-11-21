// Study Groups: create a group.

import 'package:flutter/material.dart';

import '../../models/study_group.dart';
import '../../services/study_groups_api.dart';
import 'group_widgets.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _nick = TextEditingController();
  String _icon = 'initials';
  String _privacy = 'public';
  double _max = 10;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    StudyGroupsApi.nicknameHint().then((h) {
      if (mounted && _nick.text.isEmpty) _nick.text = h;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _nick.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final g = await StudyGroupsApi.create(
        name: _name.text.trim(),
        description: _desc.text.trim(),
        icon: _icon,
        privacy: _privacy,
        maxMembers: _max.round(),
        nickname: _nick.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop<StudyGroup>(context, g);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(groupErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = groupColor(0);
    return Scaffold(
      appBar: AppBar(title: const Text('Create a group')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              maxLength: 25,
              decoration: const InputDecoration(labelText: 'Group name'),
              validator: (v) {
                final t = (v ?? '').trim();
                return (t.length < 3 || t.length > 25)
                    ? 'Use 3 to 25 characters'
                    : null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _desc,
              maxLength: 150,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: 16),
            const Text('Group icon',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kGroupIcons.keys.map((k) {
                final selected = k == _icon;
                return GestureDetector(
                  onTap: () => setState(() => _icon = k),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: selected ? color : Colors.transparent, width: 2),
                    ),
                    child: GroupAvatar(
                      id: 0,
                      name: _name.text.isEmpty ? 'Group' : _name.text,
                      icon: k,
                      size: 44,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text('Who can join?',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'public',
                    icon: Icon(Icons.public_rounded),
                    label: Text('Public')),
                ButtonSegment(
                    value: 'private',
                    icon: Icon(Icons.lock_rounded),
                    label: Text('Private')),
              ],
              selected: {_privacy},
              onSelectionChanged: (s) => setState(() => _privacy = s.first),
            ),
            const SizedBox(height: 6),
            Text(
              _privacy == 'public'
                  ? 'Anyone can find it in Discover and join straight away.'
                  : 'Hidden from Discover. People join with a 6-digit code '
                      'and you approve each request.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            Text('Maximum members: ${_max.round()}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Slider(
              value: _max,
              min: 2,
              max: 20,
              divisions: 18,
              label: '${_max.round()}',
              onChanged: (v) => setState(() => _max = v),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nick,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: 'Your nickname in this group',
                helperText: 'Other members only see this, never your real name.',
              ),
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? 'At least 2 characters' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create group'),
            ),
          ],
        ),
      ),
    );
  }
}
