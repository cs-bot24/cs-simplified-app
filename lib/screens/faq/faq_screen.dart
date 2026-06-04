import 'package:flutter/material.dart';
import '../../data/faq_data.dart';
import '../../models/faq_model.dart';
import '../contact/support_center_screen.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});
  @override State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final _searchCtrl = TextEditingController();
  String _query        = '';
  int?   _expandedIdx; // which item is currently open
  String _activeCategory = 'All';

  static const _categories = [
    'All', 'General', 'Materials', 'Streak & Leaderboard',
    'Notifications', 'Support', 'Account & Privacy',
  ];

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<FaqItem> get _filtered {
    final allItems = faqData
        .where((c) => _activeCategory == 'All' || c.category == _activeCategory)
        .expand((c) => c.items)
        .toList();

    if (_query.trim().isEmpty) return allItems;

    final q = _query.toLowerCase();
    return allItems
        .where((item) =>
            item.question.toLowerCase().contains(q) ||
            item.answer.toLowerCase().contains(q) ||
            item.tags.any((t) => t.toLowerCase().contains(q)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme  = Theme.of(context).colorScheme;
    final items   = _filtered;
    final isSearch = _query.trim().isNotEmpty;

    return Scaffold(
      body: Column(children: [
        // ── Coloured header ──────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            const Text('❓', style: TextStyle(fontSize: 30)),
            const SizedBox(height: 6),
            const Text('Frequently Asked Questions',
                style: TextStyle(color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
                'Find quick answers to common questions about CS Simplified.',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 16),
            // Search bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() {
                  _query       = v;
                  _expandedIdx = null;
                }),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search FAQs...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: Colors.grey[400], size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded,
                              color: Colors.grey[400], size: 18),
                          onPressed: () => setState(() {
                            _searchCtrl.clear();
                            _query       = '';
                            _expandedIdx = null;
                          }),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                ),
              ),
            ),
          ]),
        ),

        // ── Category chips (hidden during search) ────────────────────────────
        if (!isSearch)
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final cat      = _categories[i];
                final selected = _activeCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() {
                    _activeCategory = cat;
                    _expandedIdx    = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary
                          : scheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(cat,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : scheme.primary)),
                  ),
                );
              },
            ),
          ),

        if (!isSearch) const Divider(height: 1),

        // ── FAQ list / empty state ─────────────────────────────────────────
        Expanded(
          child: items.isEmpty
              ? _EmptyState(
                  onContactTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SupportCenterScreen()),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: isSearch
                      ? items.length
                      : _buildGrouped(items).length,
                  itemBuilder: (ctx, i) {
                    if (isSearch) {
                      return _FaqTile(
                        item:       items[i],
                        index:      i,
                        isExpanded: _expandedIdx == i,
                        onTap: () => setState(() =>
                            _expandedIdx = _expandedIdx == i ? null : i),
                      );
                    }
                    final grouped = _buildGrouped(items);
                    final entry   = grouped[i];
                    if (entry is String) {
                      return _CategoryHeader(label: entry);
                    }
                    final item = entry as _IndexedItem;
                    return _FaqTile(
                      item:       item.item,
                      index:      item.globalIdx,
                      isExpanded: _expandedIdx == item.globalIdx,
                      onTap: () => setState(() =>
                          _expandedIdx =
                              _expandedIdx == item.globalIdx
                                  ? null
                                  : item.globalIdx),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  /// Returns a flat list of either String (category header) or _IndexedItem.
  List<dynamic> _buildGrouped(List<FaqItem> items) {
    final result  = <dynamic>[];
    int globalIdx = 0;

    final categories = _activeCategory == 'All'
        ? faqData.map((c) => c.category).toList()
        : [_activeCategory];

    for (final cat in categories) {
      final catItems = items
          .where((it) => it.category == cat)
          .toList();
      if (catItems.isEmpty) continue;
      result.add(cat);
      for (final item in catItems) {
        result.add(_IndexedItem(item, globalIdx++));
      }
    }
    return result;
  }
}

class _IndexedItem {
  final FaqItem item;
  final int globalIdx;
  _IndexedItem(this.item, this.globalIdx);
}

// ── FAQ tile (accordion) ──────────────────────────────────────────────────────

class _FaqTile extends StatelessWidget {
  final FaqItem item;
  final int     index;
  final bool    isExpanded;
  final VoidCallback onTap;

  const _FaqTile({
    required this.item, required this.index,
    required this.isExpanded, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? scheme.primary.withOpacity(0.35)
              : Colors.grey.withOpacity(0.15),
        ),
        boxShadow: isExpanded
            ? [BoxShadow(color: scheme.primary.withOpacity(0.06),
                blurRadius: 8, offset: const Offset(0, 3))]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(item.question,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isExpanded ? scheme.primary : null)),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: isExpanded
                            ? scheme.primary
                            : Colors.grey[400],
                        size: 22),
                  ),
                ]),
                // Animated answer reveal
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: Colors.grey.withOpacity(0.15),
                            height: 1),
                        const SizedBox(height: 12),
                        Text(item.answer,
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.65,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withOpacity(0.8))),
                      ],
                    ),
                  ),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 220),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Category header ───────────────────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  final String label;
  const _CategoryHeader({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 8, 0, 8),
    child: Text(label,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 0.3)),
  );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onContactTap;
  const _EmptyState({required this.onContactTap});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text('No matching FAQ found.',
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color)),
        const SizedBox(height: 8),
        Text('Need help?',
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onContactTap,
          icon: const Icon(Icons.support_agent_rounded, size: 18),
          label: const Text('Contact Support'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    ),
  );
}
