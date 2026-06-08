import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/ai_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/ai_model.dart';

class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key});

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _inputFocus = FocusNode();

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
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _inputFocus.unfocus();
    await context.read<AiProvider>().ask(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;

    // ── Auth gate ──────────────────────────────────────────────────────────────
    if (!auth.isLoggedIn) {
      return _NotLoggedInView(scheme: scheme);
    }

    // ── Premium gate ───────────────────────────────────────────────────────────
    // Phase 2.0: all logged-in users are premium.
    // Future: replace `true` with `auth.user?.isPremium ?? false`
    const bool isPremium = true;
    if (!isPremium) {
      return _UpgradeView(scheme: scheme);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Tutor'),
        actions: [
          Consumer<AiProvider>(
            builder: (_, ai, __) => ai.messages.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded),
                    tooltip: 'Clear conversation',
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Clear conversation?'),
                        content: const Text(
                            'This will remove all messages from this session.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel')),
                          TextButton(
                            onPressed: () {
                              context.read<AiProvider>().clearConversation();
                              Navigator.pop(context);
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Header info strip ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: scheme.primary.withOpacity(0.07),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 14, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ask academic questions about Computer Science and related subjects.',
                    style: TextStyle(fontSize: 12, color: scheme.primary),
                  ),
                ),
              ],
            ),
          ),

          // ── Message list ───────────────────────────────────────────────────
          Expanded(
            child: Consumer<AiProvider>(
              builder: (_, ai, __) {
                if (ai.messages.isEmpty) {
                  return _EmptyState(scheme: scheme);
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: ai.messages.length + (ai.loading ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (ai.loading && i == ai.messages.length) {
                      return const _TypingIndicator();
                    }
                    return _MessageBubble(
                        message: ai.messages[i], scheme: scheme);
                  },
                );
              },
            ),
          ),

          // ── Error banner ───────────────────────────────────────────────────
          Consumer<AiProvider>(
            builder: (_, ai, __) => ai.error != null
                ? _ErrorBanner(
                    error: ai.error!,
                    scheme: scheme,
                    onDismiss: () => context.read<AiProvider>().clearError(),
                  )
                : const SizedBox.shrink(),
          ),

          // ── Input bar ──────────────────────────────────────────────────────
          Consumer<AiProvider>(
            builder: (_, ai, __) => _InputBar(
              controller: _controller,
              focusNode: _inputFocus,
              loading: ai.loading,
              onSend: _send,
              scheme: scheme,
            ),
          ),
        ],
      ),
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 12, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'CS Simplified AI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            SelectableText(
              message.text,
              style: TextStyle(
                fontSize: 14,
                color: isUser
                    ? Colors.white
                    : (isDark ? Colors.white87 : Colors.black87),
                height: 1.45,
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
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
            topLeft:     Radius.circular(16),
            topRight:    Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft:  Radius.circular(4),
          ),
        ),
        child: FadeTransition(
          opacity: _anim,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 13, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'AI is thinking...',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Input Bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  final VoidCallback onSend;
  final ColorScheme scheme;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.loading,
    required this.onSend,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        children: [
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFF0F4FF),
              ),
            ),
          ),
          const SizedBox(width: 8),
          loading
              ? Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Material(
                  color: scheme.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onSend,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.send_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
        ],
      ),
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
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.auto_awesome_rounded,
                size: 40, color: scheme.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'CS Simplified AI Tutor',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask academic questions and get clear, structured explanations.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          _SuggestionChip(
            label: 'Explain the OSI Model',
            icon: Icons.layers_rounded,
            scheme: scheme,
          ),
          const SizedBox(height: 8),
          _SuggestionChip(
            label: 'What is Big O notation?',
            icon: Icons.functions_rounded,
            scheme: scheme,
          ),
          const SizedBox(height: 8),
          _SuggestionChip(
            label: 'Which is not an OS: Linux, Windows, Oracle, Android?',
            icon: Icons.quiz_rounded,
            scheme: scheme,
          ),
          const SizedBox(height: 8),
          _SuggestionChip(
            label: 'Explain the difference between TCP and UDP',
            icon: Icons.compare_arrows_rounded,
            scheme: scheme,
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final ColorScheme scheme;

  const _SuggestionChip({
    required this.label,
    required this.icon,
    required this.scheme,
  });

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
        child: Row(
          children: [
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 13, color: scheme.primary)),
            ),
            Icon(Icons.north_west_rounded,
                size: 14, color: scheme.primary.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

// ── Error Banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String error;
  final ColorScheme scheme;
  final VoidCallback onDismiss;

  const _ErrorBanner(
      {required this.error,
      required this.scheme,
      required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(error,
                style: const TextStyle(fontSize: 13, color: Colors.red)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                color: Colors.red, size: 16),
          ),
        ],
      ),
    );
  }
}

// ── Upgrade View ──────────────────────────────────────────────────────────────

class _UpgradeView extends StatelessWidget {
  final ColorScheme scheme;
  const _UpgradeView({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Tutor')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.lock_rounded,
                    size: 36, color: Colors.amber),
              ),
              const SizedBox(height: 20),
              const Text(
                'AI Tutor is a Premium Feature',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Upgrade to Pro to access AI-powered learning assistance.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Pro subscription coming soon!')),
                    );
                  },
                  child: const Text('Upgrade to Pro'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Not Logged In View ────────────────────────────────────────────────────────

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_circle_rounded,
                  size: 64, color: scheme.primary),
              const SizedBox(height: 16),
              const Text('Sign in to use AI Tutor',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'AI Tutor is available to registered students.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
