import 'dart:typed_data';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/achievement_provider.dart';
import '../../services/sharing_service.dart';
import 'cards/streak_card.dart';

class ShareProgressScreen extends StatefulWidget {
  /// Optional: pre-select a tab index.
  /// 0=Streak, 1=Rank, 2=Achievement, 3=Milestone
  final int initialTab;
  const ShareProgressScreen({super.key, this.initialTab = 0});
  @override
  State<ShareProgressScreen> createState() => _ShareProgressScreenState();
}

class _ShareProgressScreenState extends State<ShareProgressScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // RepaintBoundary keys — one per card
  final _streakKey  = GlobalKey();
  final _rankKey    = GlobalKey();
  final _achieveKey = GlobalKey();
  final _mileKey    = GlobalKey();

  Map<String, dynamic>? _cardData;
  bool    _loading   = true;
  String? _error;
  bool    _capturing = false;

  static const _tabLabels = ['Streak', 'Rank', 'Achievement', 'Milestone'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: 4, vsync: this, initialIndex: widget.initialTab);
    _loadCardData();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadCardData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.getShareCardData();
      setState(() => _cardData = data as Map<String, dynamic>);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  GlobalKey get _currentKey {
    switch (_tabs.index) {
      case 1: return _rankKey;
      case 2: return _achieveKey;
      case 3: return _mileKey;
      default: return _streakKey;
    }
  }

  String get _currentCardType => ['streak', 'rank', 'achievement', 'milestone'][_tabs.index];

  Future<Uint8List?> _capture() async {
    setState(() => _capturing = true);
    // Small delay so the widget is fully laid out
    await Future.delayed(const Duration(milliseconds: 80));
    final bytes = await SharingService.captureWidget(_currentKey);
    setState(() => _capturing = false);
    return bytes;
  }

  Future<void> _share() async {
    final bytes = await _capture();
    if (bytes == null || !mounted) {
      _snack('Could not capture card. Try again.', success: false);
      return;
    }
    final ok = await SharingService.shareImage(bytes, cardType: _currentCardType);
    if (!ok && mounted) _snack('Sharing failed.', success: false);
  }

  Future<void> _save() async {
    final bytes = await _capture();
    if (bytes == null || !mounted) {
      _snack('Could not capture card. Try again.', success: false);
      return;
    }
    final ok = await SharingService.saveToGallery(bytes, cardType: _currentCardType);
    if (mounted) {
      // Windows saves via a Save File dialog (see sharing_service_io.dart),
      // not a photo gallery — "Saved to gallery!" would be inaccurate there.
      final isWindows = defaultTargetPlatform == TargetPlatform.windows;
      final successMsg = isWindows ? 'Image saved!' : 'Saved to gallery!';
      final failureMsg = isWindows
          ? 'Could not save image.'
          : 'Could not save. Check storage permission.';
      _snack(ok ? successMsg : failureMsg, success: ok);
    }
  }

  void _snack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: Duration(seconds: success ? 3 : 5),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Progress'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _loadCardData, child: const Text('Retry')),
                ]))
              : Column(
                  children: [
                    // ── Card preview ───────────────────────────────────────
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _CardPreview(
                            repaintKey: _streakKey,
                            child: StreakShareCard(
                              displayName:   _cardData!['display_name'] ?? '',
                              currentStreak: _cardData!['current_streak'] ?? 0,
                              longestStreak: _cardData!['longest_streak'] ?? 0,
                              totalStudyDays: _cardData!['total_study_days'] ?? 0,
                            ),
                          ),
                          _CardPreview(
                            repaintKey: _rankKey,
                            child: RankShareCard(
                              displayName:    _cardData!['display_name'] ?? '',
                              rank:           _cardData!['rank'] ?? 0,
                              currentStreak:  _cardData!['current_streak'] ?? 0,
                              totalStudyDays: _cardData!['total_study_days'] ?? 0,
                              materialsOpened: _cardData!['materials_opened'] ?? 0,
                              mode: 'all_time',
                            ),
                          ),
                          _CardPreview(
                            repaintKey: _achieveKey,
                            child: _cardData!['recent_achievement'] != null
                                ? AchievementShareCard(
                                    displayName:
                                        _cardData!['display_name'] ?? '',
                                    achievementIcon:
                                        _cardData!['recent_achievement']['icon'] ?? '🏅',
                                    achievementTitle:
                                        _cardData!['recent_achievement']['title'] ?? '',
                                    achievementDescription:
                                        _cardData!['recent_achievement']['description'] ?? '',
                                    badgeType:
                                        _cardData!['recent_achievement']['badge_type'] ?? 'bronze',
                                  )
                                : _NoAchievementPlaceholder(),
                          ),
                          _CardPreview(
                            repaintKey: _mileKey,
                            child: MilestoneShareCard(
                              displayName:          _cardData!['display_name'] ?? '',
                              totalStudyDays:       _cardData!['total_study_days'] ?? 0,
                              materialsOpened:      _cardData!['materials_opened'] ?? 0,
                              achievementsUnlocked: _cardData!['achievements_unlocked'] ?? 0,
                              longestStreak:        _cardData!['longest_streak'] ?? 0,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Action buttons ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12, offset: const Offset(0, -3)),
                        ],
                      ),
                      child: Row(children: [
                        // Save to gallery
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.download_rounded,
                            label: 'Save',
                            color: Colors.teal,
                            loading: _capturing,
                            onTap: _save,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Share via system sheet
                        Expanded(
                          flex: 2,
                          child: _ActionButton(
                            icon: Icons.share_rounded,
                            label: 'Share',
                            color: scheme.primary,
                            loading: _capturing,
                            onTap: _share,
                            filled: true,
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
    );
  }
}

// ── Card preview wrapper ──────────────────────────────────────────────────────

class _CardPreview extends StatelessWidget {
  final GlobalKey repaintKey;
  final Widget child;
  const _CardPreview({required this.repaintKey, required this.child});

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Preview',
              style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          const SizedBox(height: 12),
          // Shadow wrapper
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: RepaintBoundary(
                key: repaintKey,
                child: child,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tap Share to post on WhatsApp, Telegram,\nInstagram, or any app',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[400], height: 1.5),
          ),
        ],
      ),
    ),
  );
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool loading, filled;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon, required this.label, required this.color,
    required this.loading, required this.onTap, this.filled = false,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: loading ? null : onTap,
    icon: loading
        ? const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Icon(icon, size: 18),
    label: Text(label),
    style: ElevatedButton.styleFrom(
      backgroundColor: filled ? color : color.withOpacity(0.1),
      foregroundColor: filled ? Colors.white : color,
      elevation: filled ? 2 : 0,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

// ── No achievement placeholder ────────────────────────────────────────────────

class _NoAchievementPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 360,
    height: 360,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🔒', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text('No achievements yet',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Study a material for 3+ minutes\nto unlock your first badge',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ]),
    ),
  );
}
