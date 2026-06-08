import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/ai_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/ai_model.dart';

class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key});
  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen>
    with SingleTickerProviderStateMixin {
  final _controller  = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _inputFocus  = FocusNode();
  File? _pickedImage;
  bool  _showSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ai = context.read<AiProvider>();
      ai.loadPlan();
      ai.loadUsage();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final ai   = context.read<AiProvider>();
    final text = _controller.text.trim();
    if (text.isEmpty && _pickedImage == null) return;
    _controller.clear();
    _inputFocus.unfocus();
    final img = _pickedImage;
    setState(() => _pickedImage = null);

    if (img != null) {
      await ai.askWithImage(img, extraText: text);
    } else {
      await ai.ask(text);
    }
    _scrollToBottom();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked != null) {
        setState(() => _pickedImage = File(picked.path));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access camera or gallery.')),
        );
      }
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showPracticeDialog(BuildContext context) {
    final ai = context.read<AiProvider>();
    final lastAiMsg = ai.messages.lastWhere(
      (m) => !m.isUser,
      orElse: () => AiMessage(text: '', isUser: false, timestamp: DateTime.now()),
    );
    final topic = lastAiMsg.subject ?? 'the topic we just discussed';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PracticeDialog(topic: topic),
    );
  }

  void _showStudyNotesDialog(BuildContext context) {
    final ai = context.read<AiProvider>();
    final lastAiMsg = ai.messages.lastWhere(
      (m) => !m.isUser,
      orElse: () => AiMessage(text: '', isUser: false, timestamp: DateTime.now()),
    );
    final topic = lastAiMsg.subject ?? 'the topic we just discussed';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StudyNotesDialog(topic: topic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;

    if (!auth.isLoggedIn) return _NotLoggedInView(scheme: scheme);

    return Scaffold(
      appBar: _buildAppBar(scheme),
      body: Column(
        children: [
          _ModeBar(scheme: scheme),
          if (_showSettings) _SettingsPanel(scheme: scheme),
          Expanded(child: _MessageList(scrollCtrl: _scrollCtrl, scheme: scheme)),
          Consumer<AiProvider>(
            builder: (_, ai, __) => ai.error != null
                ? _ErrorBanner(error: ai.error!, scheme: scheme,
                    onDismiss: () => context.read<AiProvider>().clearError())
                : const SizedBox.shrink(),
          ),
          if (_pickedImage != null) _ImagePreview(
            image: _pickedImage!,
            onRemove: () => setState(() => _pickedImage = null),
            scheme: scheme,
          ),
          _InputBar(
            controller: _controller,
            focusNode: _inputFocus,
            hasImage: _pickedImage != null,
            onSend: _send,
            onImageTap: _showImageOptions,
            scheme: scheme,
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(ColorScheme scheme) {
    return AppBar(
      title: Consumer<AiProvider>(
        builder: (_, ai, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Tutor', style: TextStyle(fontSize: 17)),
            if (ai.questionsToday > 0)
              Text('${ai.questionsToday} questions today',
                  style: TextStyle(fontSize: 11, color: scheme.primary.withOpacity(0.7))),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(_showSettings ? Icons.tune : Icons.tune_outlined),
          tooltip: 'Settings',
          onPressed: () => setState(() => _showSettings = !_showSettings),
        ),
        Consumer<AiProvider>(
          builder: (_, ai, __) {
            if (ai.messages.isEmpty) return const SizedBox.shrink();
            return PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (val) {
                switch (val) {
                  case 'practice':   _showPracticeDialog(context); break;
                  case 'notes':      _showStudyNotesDialog(context); break;
                  case 'clear':      _confirmClear(context); break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'practice',
                    child: ListTile(leading: Icon(Icons.quiz_rounded), title: Text('Practice Questions'), dense: true)),
                const PopupMenuItem(value: 'notes',
                    child: ListTile(leading: Icon(Icons.notes_rounded), title: Text('Study Notes'), dense: true)),
                const PopupMenuItem(value: 'clear',
                    child: ListTile(leading: Icon(Icons.delete_sweep_rounded), title: Text('Clear Chat'), dense: true)),
              ],
            );
          },
        ),
      ],
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text('All messages in this session will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () { context.read<AiProvider>().clearConversation(); Navigator.pop(context); },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}


// ── Mode Bar ──────────────────────────────────────────────────────────────────

class _ModeBar extends StatelessWidget {
  final ColorScheme scheme;
  const _ModeBar({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiProvider>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: scheme.primary.withOpacity(0.05),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 13, color: scheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Academic questions only • ${ai.level.name[0].toUpperCase()}${ai.level.name.substring(1)} level',
              style: TextStyle(fontSize: 11, color: scheme.primary),
            ),
          ),
          GestureDetector(
            onTap: () => context.read<AiProvider>().toggleExamPrep(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ai.isExamPrep
                    ? scheme.primary
                    : scheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_rounded,
                      size: 12,
                      color: ai.isExamPrep ? Colors.white : scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Exam Prep',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ai.isExamPrep ? Colors.white : scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ── Settings Panel ────────────────────────────────────────────────────────────

class _SettingsPanel extends StatelessWidget {
  final ColorScheme scheme;
  const _SettingsPanel({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiProvider>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A2E)
            : const Color(0xFFF8F9FF),
        border: Border(bottom: BorderSide(color: scheme.primary.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Explanation Level',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary)),
          const SizedBox(height: 8),
          Row(
            children: ExplanationLevel.values.map((lvl) {
              final selected = ai.level == lvl;
              final labels = {
                ExplanationLevel.beginner:     'Beginner',
                ExplanationLevel.intermediate: 'Intermediate',
                ExplanationLevel.advanced:     'Advanced',
              };
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => context.read<AiProvider>().setLevel(lvl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? scheme.primary : scheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        labels[lvl]!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : scheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}


// ── Message List ──────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  final ScrollController scrollCtrl;
  final ColorScheme scheme;
  const _MessageList({required this.scrollCtrl, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiProvider>();
    if (ai.messages.isEmpty) return _EmptyState(scheme: scheme);
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: ai.messages.length + (ai.loading ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (ai.loading && i == ai.messages.length) return const _TypingIndicator();
        return _MessageBubble(message: ai.messages[i], scheme: scheme);
      },
    );
  }
}


// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final AiMessage message;
  final ColorScheme scheme;
  const _MessageBubble({required this.message, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? scheme.primary
              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F4FF)),
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 12, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text('CS Simplified AI',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.primary)),
                  if (message.subject != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: scheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(message.subject!,
                          style: TextStyle(fontSize: 9, color: scheme.primary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  if (message.mode == AiMode.examPrep) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('EXAM', style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
            ],
            SelectableText(
              message.text,
              style: TextStyle(
                fontSize: 14,
                color: isUser ? Colors.white : (isDark ? Colors.white.withOpacity(0.87) : Colors.black87),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Typing Indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override State<_TypingIndicator> createState() => _TypingIndicatorState();
}
class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F4FF),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16),
            bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4),
          ),
        ),
        child: FadeTransition(
          opacity: _anim,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome_rounded, size: 13, color: scheme.primary),
            const SizedBox(width: 6),
            Text('AI is thinking...', style: TextStyle(fontSize: 13, color: scheme.primary, fontStyle: FontStyle.italic)),
          ]),
        ),
      ),
    );
  }
}


// ── Image Preview ─────────────────────────────────────────────────────────────

class _ImagePreview extends StatelessWidget {
  final File image;
  final VoidCallback onRemove;
  final ColorScheme scheme;
  const _ImagePreview({required this.image, required this.onRemove, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.primary.withOpacity(0.2)),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(image, width: 48, height: 48, fit: BoxFit.cover),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text('Image attached — add a note or send as-is',
            style: TextStyle(fontSize: 12, color: scheme.primary))),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          color: scheme.primary,
          onPressed: onRemove,
        ),
      ]),
    );
  }
}


// ── Input Bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasImage;
  final bool loading;
  final VoidCallback onSend;
  final VoidCallback onImageTap;
  final ColorScheme scheme;

  const _InputBar({
    required this.controller, required this.focusNode,
    required this.hasImage,   required this.onSend,
    required this.onImageTap, required this.scheme,
    this.loading = false,
  });

  // Extract loading from provider at build time
  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AiProvider>().loading;
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      padding: EdgeInsets.only(left: 8, right: 12, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
      child: Row(children: [
        // Image attach button
        IconButton(
          icon: Icon(
            hasImage ? Icons.image_rounded : Icons.add_photo_alternate_outlined,
            color: hasImage ? scheme.primary : Colors.grey,
          ),
          onPressed: loading ? null : onImageTap,
          tooltip: 'Attach image question',
        ),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: !loading,
            maxLength: 2000,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Ask a question...',
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              filled: true,
              fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F4FF),
            ),
          ),
        ),
        const SizedBox(width: 8),
        loading
            ? Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: scheme.primary.withOpacity(0.12), shape: BoxShape.circle),
                child: const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : Material(
                color: scheme.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSend,
                  child: const Padding(padding: EdgeInsets.all(10),
                      child: Icon(Icons.send_rounded, color: Colors.white, size: 22)),
                ),
              ),
      ]),
    );
  }
}


// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final ColorScheme scheme;
  const _EmptyState({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 16),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: scheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(24)),
          child: Icon(Icons.auto_awesome_rounded, size: 40, color: scheme.primary),
        ),
        const SizedBox(height: 20),
        Text('CS Simplified AI Tutor',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: scheme.primary)),
        const SizedBox(height: 8),
        Text('Ask academic questions, solve past questions, generate practice sets, and create study notes.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
        const SizedBox(height: 28),
        _SuggestionChip(label: 'Explain the OSI Model', icon: Icons.layers_rounded, scheme: scheme),
        const SizedBox(height: 8),
        _SuggestionChip(label: 'What is Big O notation?', icon: Icons.functions_rounded, scheme: scheme),
        const SizedBox(height: 8),
        _SuggestionChip(label: 'Which is not an OS: Linux, Windows, Oracle, Android?', icon: Icons.quiz_rounded, scheme: scheme),
        const SizedBox(height: 8),
        _SuggestionChip(label: 'Summarize this topic: Binary Trees', icon: Icons.notes_rounded, scheme: scheme),
        const SizedBox(height: 8),
        _SuggestionChip(label: 'Explain the difference between TCP and UDP', icon: Icons.compare_arrows_rounded, scheme: scheme),
      ]),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final ColorScheme scheme;
  const _SuggestionChip({required this.label, required this.icon, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.read<AiProvider>().ask(label),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.primary.withOpacity(0.15)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: scheme.primary))),
          Icon(Icons.north_west_rounded, size: 14, color: scheme.primary.withOpacity(0.5)),
        ]),
      ),
    );
  }
}


// ── Error Banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String error;
  final ColorScheme scheme;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.error, required this.scheme, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(error, style: const TextStyle(fontSize: 13, color: Colors.red))),
        GestureDetector(onTap: onDismiss, child: const Icon(Icons.close_rounded, color: Colors.red, size: 16)),
      ]),
    );
  }
}


// ── Practice Questions Dialog ─────────────────────────────────────────────────

class _PracticeDialog extends StatefulWidget {
  final String topic;
  const _PracticeDialog({required this.topic});
  @override State<_PracticeDialog> createState() => _PracticeDialogState();
}
class _PracticeDialogState extends State<_PracticeDialog> {
  String? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final result = await context.read<AiProvider>().generatePracticeQuestions(widget.topic);
    if (mounted) setState(() { _result = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Practice Questions'),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Text(_result ?? 'Could not generate questions. Please try again.',
                    style: const TextStyle(fontSize: 14, height: 1.5)),
              ),
      ),
      actions: [
        if (!_loading) TextButton(onPressed: _generate, child: const Text('Regenerate')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}


// ── Study Notes Dialog ────────────────────────────────────────────────────────

class _StudyNotesDialog extends StatefulWidget {
  final String topic;
  const _StudyNotesDialog({required this.topic});
  @override State<_StudyNotesDialog> createState() => _StudyNotesDialogState();
}
class _StudyNotesDialogState extends State<_StudyNotesDialog> {
  String? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final result = await context.read<AiProvider>().generateStudyNotes(widget.topic);
    if (mounted) setState(() { _result = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Study Notes'),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Text(_result ?? 'Could not generate notes. Please try again.',
                    style: const TextStyle(fontSize: 14, height: 1.5)),
              ),
      ),
      actions: [
        if (!_loading) TextButton(onPressed: _generate, child: const Text('Regenerate')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}


// ── Not Logged In ─────────────────────────────────────────────────────────────

class _NotLoggedInView extends StatelessWidget {
  final ColorScheme scheme;
  const _NotLoggedInView({required this.scheme});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Tutor')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.account_circle_rounded, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            const Text('Sign in to use AI Tutor', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('AI Tutor is available to registered students.', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
          ]),
        ),
      ),
    );
  }
}
