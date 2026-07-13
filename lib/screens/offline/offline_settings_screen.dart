import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/offline_provider.dart';
import '../../services/offline/storage_manager.dart';

/// Settings screen for the two user-configurable knobs from the spec:
///   • Download using: Wi-Fi only / Wi-Fi + Mobile Data
///   • Auto Cleanup: delete PDFs not opened for 30 / 60 days / Never
class OfflineSettingsScreen extends StatefulWidget {
  const OfflineSettingsScreen({super.key});

  @override
  State<OfflineSettingsScreen> createState() => _OfflineSettingsScreenState();
}

class _OfflineSettingsScreenState extends State<OfflineSettingsScreen> {
  DownloadNetworkPreference? _networkPref;
  AutoCleanupPolicy? _cleanupPolicy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final offline = context.read<OfflineProvider>();
    final network = await offline.getNetworkPreference();
    final cleanup = await offline.getCleanupPolicy();
    if (mounted) setState(() { _networkPref = network; _cleanupPolicy = cleanup; });
  }

  @override
  Widget build(BuildContext context) {
    if (_networkPref == null || _cleanupPolicy == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final offline = context.read<OfflineProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Offline Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          const _SectionLabel('Download using'),
          RadioListTile<DownloadNetworkPreference>(
            title: const Text('Wi-Fi only'),
            subtitle: const Text('Downloads pause automatically on mobile data'),
            value: DownloadNetworkPreference.wifiOnly,
            groupValue: _networkPref,
            onChanged: (v) async {
              if (v == null) return;
              await offline.setNetworkPreference(v);
              setState(() => _networkPref = v);
            },
          ),
          RadioListTile<DownloadNetworkPreference>(
            title: const Text('Wi-Fi + Mobile Data'),
            value: DownloadNetworkPreference.wifiAndData,
            groupValue: _networkPref,
            onChanged: (v) async {
              if (v == null) return;
              await offline.setNetworkPreference(v);
              setState(() => _networkPref = v);
            },
          ),
          const Divider(height: 32),
          const _SectionLabel('Auto Cleanup'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Automatically delete downloaded materials that haven\u2019t been opened '
              'in a while, to save space.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          ...AutoCleanupPolicy.values.map((policy) => RadioListTile<AutoCleanupPolicy>(
                title: Text(policy.label),
                value: policy,
                groupValue: _cleanupPolicy,
                onChanged: (v) async {
                  if (v == null) return;
                  await offline.setCleanupPolicy(v);
                  setState(() => _cleanupPolicy = v);
                },
              )),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
            )),
      );
}
