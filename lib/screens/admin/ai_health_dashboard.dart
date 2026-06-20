// lib/screens/admin/ai_health_dashboard.dart
//
// AI System Health Dashboard — Admin only
//
// Shows live status of every AI provider, telemetry counters, and cache stats.
// Calls GET /api/v1/ai/system-health (admin JWT required).
//
// Tap the refresh button or pull-to-refresh to re-fetch.

import 'package:flutter/material.dart';
import '../../core/api_client.dart';

class AiHealthDashboard extends StatefulWidget {
  const AiHealthDashboard({super.key});

  @override
  State<AiHealthDashboard> createState() => _AiHealthDashboardState();
}

class _AiHealthDashboardState extends State<AiHealthDashboard> {
  bool _loading = true;
  String? _error;
  List<dynamic> _providers = [];
  Map<String, dynamic> _telemetry = {};
  Map<String, dynamic> _cache = {};
  DateTime? _lastFetched;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.getAiSystemHealth();
      setState(() {
        _providers    = data['providers']  as List<dynamic>? ?? [];
        _telemetry    = data['telemetry']  as Map<String, dynamic>? ?? {};
        _cache        = data['cache']      as Map<String, dynamic>? ?? {};
        _lastFetched  = DateTime.now();
        _loading      = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI System Health'),
        actions: [
          if (_lastFetched != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  _timeAgo(_lastFetched!),
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _fetch,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(error: _error!, onRetry: _fetch)
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Summary bar ───────────────────────────────────
                        _SummaryBar(providers: _providers),
                        const SizedBox(height: 20),

                        // ── Provider cards ────────────────────────────────
                        _SectionHeader(
                          icon: Icons.hub_rounded,
                          label: 'Provider Status',
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 10),
                        ..._providers.map((p) => _ProviderCard(
                          data: p as Map<String, dynamic>,
                          isDark: isDark,
                        )),
                        const SizedBox(height: 20),

                        // ── Telemetry ─────────────────────────────────────
                        _SectionHeader(
                          icon: Icons.analytics_rounded,
                          label: 'Telemetry (since last restart)',
                          color: Colors.purple,
                        ),
                        const SizedBox(height: 10),
                        _TelemetryGrid(data: _telemetry),
                        const SizedBox(height: 20),

                        // ── Cache ─────────────────────────────────────────
                        _SectionHeader(
                          icon: Icons.memory_rounded,
                          label: 'Response Cache',
                          color: Colors.teal,
                        ),
                        const SizedBox(height: 10),
                        _CacheCard(data: _cache),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Updated ${diff.inSeconds}s ago';
    return 'Updated ${diff.inMinutes}m ago';
  }
}

// ── Summary bar (X healthy / Y total) ────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final List<dynamic> providers;
  const _SummaryBar({required this.providers});

  @override
  Widget build(BuildContext context) {
    final healthy   = providers.where((p) => p['healthy'] == true).length;
    final total     = providers.length;
    final allOk     = healthy == total;
    final anyDown   = healthy < total ~/ 2;  // more than half down = red
    final color     = allOk ? Colors.green : anyDown ? Colors.red : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(
          allOk ? Icons.check_circle_rounded
              : anyDown ? Icons.error_rounded
              : Icons.warning_rounded,
          color: color, size: 28,
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              allOk ? 'All systems operational'
                  : anyDown ? 'Multiple providers down'
                  : 'Some providers degraded',
              style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: color,
              ),
            ),
            Text(
              '$healthy of $total providers healthy',
              style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
            ),
          ],
        )),
      ]),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionHeader({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: color),
    const SizedBox(width: 8),
    Text(label, style: TextStyle(
      fontSize: 15, fontWeight: FontWeight.bold, color: color,
    )),
  ]);
}

// ── Provider card ─────────────────────────────────────────────────────────────

class _ProviderCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  const _ProviderCard({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final name         = data['name']          as String? ?? '';
    final healthy      = data['healthy']       as bool?   ?? false;
    final latencyMs    = (data['latency_ms']   as num?)?.toDouble() ?? 0.0;
    final failureCount = data['failure_count'] as int?    ?? 0;
    final totalCalls   = data['total_calls']   as int?    ?? 0;
    final totalErrors  = data['total_errors']  as int?    ?? 0;
    final lastSuccess  = data['last_success']  as num?    ?? 0;
    final lastFailure  = data['last_failure']  as num?    ?? 0;

    final statusColor  = healthy ? Colors.green : Colors.red;
    final errorRate    = totalCalls > 0
        ? (totalErrors / totalCalls * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: healthy ? Colors.green : Colors.red,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: statusColor.withOpacity(0.4),
                  blurRadius: 6,
                )],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(name, style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14,
            ))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                healthy ? 'HEALTHY' : 'UNHEALTHY',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: statusColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // Metrics row
          Row(children: [
            _MetricChip(
              label: 'Latency',
              value: latencyMs > 0 ? '${latencyMs.round()}ms' : '—',
              icon: Icons.speed_rounded,
              color: _latencyColor(latencyMs),
            ),
            const SizedBox(width: 8),
            _MetricChip(
              label: 'Calls',
              value: '$totalCalls',
              icon: Icons.call_made_rounded,
              color: Colors.blue,
            ),
            const SizedBox(width: 8),
            _MetricChip(
              label: 'Error rate',
              value: '$errorRate%',
              icon: Icons.error_outline_rounded,
              color: totalErrors > 0 ? Colors.orange : Colors.green,
            ),
          ]),
          if (failureCount > 0 || lastFailure > 0) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.warning_amber_rounded, size: 13, color: Colors.orange[700]),
              const SizedBox(width: 4),
              Text(
                'Consecutive failures: $failureCount'
                '${lastFailure > 0 ? "  ·  Last failure: ${_epochToAgo(lastFailure)}" : ""}',
                style: TextStyle(fontSize: 11, color: Colors.orange[700]),
              ),
            ]),
          ],
          if (lastSuccess > 0) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.check_circle_outline_rounded, size: 13, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                'Last success: ${_epochToAgo(lastSuccess)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Color _latencyColor(double ms) {
    if (ms == 0)    return Colors.grey;
    if (ms < 1000)  return Colors.green;
    if (ms < 3000)  return Colors.orange;
    return Colors.red;
  }

  String _epochToAgo(num epoch) {
    if (epoch == 0) return 'never';
    final dt   = DateTime.fromMillisecondsSinceEpoch((epoch * 1000).round());
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _MetricChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MetricChip({
    required this.label, required this.value,
    required this.icon,  required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 9, color: color, letterSpacing: 0.3)),
          ]),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.bold, color: color,
          )),
        ],
      ),
    ),
  );
}

// ── Telemetry grid ────────────────────────────────────────────────────────────

class _TelemetryGrid extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TelemetryGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = [
      _TelItem(
        label: 'Provider Retries',
        value: '${data['provider_retries'] ?? 0}',
        icon: Icons.replay_rounded,
        color: Colors.orange,
      ),
      _TelItem(
        label: 'Empty Responses',
        value: '${data['empty_responses'] ?? 0}',
        icon: Icons.inbox_rounded,
        color: Colors.red,
      ),
      _TelItem(
        label: 'LaTeX Repaired',
        value: '${data['latex_repaired'] ?? 0}',
        icon: Icons.functions_rounded,
        color: Colors.indigo,
      ),
      _TelItem(
        label: 'Mermaid Repaired',
        value: '${data['mermaid_repaired'] ?? 0}',
        icon: Icons.account_tree_rounded,
        color: Colors.teal,
      ),
      _TelItem(
        label: 'Quiz Regenerations',
        value: '${data['quiz_regenerations'] ?? 0}',
        icon: Icons.quiz_rounded,
        color: Colors.purple,
      ),
      _TelItem(
        label: 'Renderer Failures',
        value: '${data['renderer_failures'] ?? 0}',
        icon: Icons.broken_image_rounded,
        color: Colors.red[700]!,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: items.map((item) => _TelCard(item: item)).toList(),
    );
  }
}

class _TelItem {
  final String label, value;
  final IconData icon;
  final Color color;
  const _TelItem({required this.label, required this.value, required this.icon, required this.color});
}

class _TelCard extends StatelessWidget {
  final _TelItem item;
  const _TelCard({required this.item});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: item.color.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, color: item.color, size: 20),
        const SizedBox(height: 6),
        Text(item.value, style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold, color: item.color,
        )),
        const SizedBox(height: 2),
        Text(item.label, style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

// ── Cache card ────────────────────────────────────────────────────────────────

class _CacheCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CacheCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final backend    = data['backend']     as String? ?? 'memory';
    final memSize    = data['memory_size'] as int?    ?? 0;
    final isRedis    = backend == 'redis';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isRedis ? Icons.storage_rounded : Icons.memory_rounded,
            color: Colors.teal, size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRedis ? 'Redis Cache' : 'In-Memory Cache',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 3),
            Text(
              isRedis
                  ? 'Persistent · Survives restarts'
                  : 'Ephemeral · Clears on restart · Set REDIS_URL to persist',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        )),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$memSize', style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal,
            )),
            Text('entries', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ]),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          const Text('Could not load health data',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(error, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
