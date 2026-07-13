import 'dart:async';

import 'package:flutter/material.dart';

import '../core/connectivity_service.dart';

/// A small, non-blocking "Offline Mode" banner — no popup, no dialog.
///
/// Wrap the app once via `MaterialApp(builder: (context, child) =>
/// OfflineModeBanner(child: child!))`. Downloaded PDFs keep working
/// regardless of what this shows; it's purely informational.
///
/// Reads from the shared [ConnectivityService] rather than keeping its own
/// `connectivity_plus` subscription, so there's exactly one listener (and
/// one definition of "online") for the whole app.
class OfflineModeBanner extends StatefulWidget {
  final Widget child;
  const OfflineModeBanner({super.key, required this.child});

  @override
  State<OfflineModeBanner> createState() => _OfflineModeBannerState();
}

class _OfflineModeBannerState extends State<OfflineModeBanner> {
  late bool _offline = ConnectivityService.instance.isOffline;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ConnectivityService.instance.onStatusChange.listen((online) {
      if (mounted) setState(() => _offline = !online);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_offline)
        Positioned(
          top: MediaQuery.of(context).padding.top,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.black87,
                child: const Text(
                  'Offline Mode',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}
