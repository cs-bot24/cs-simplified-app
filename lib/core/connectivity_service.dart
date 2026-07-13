import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Single source of truth for "are we online right now" across the app.
///
/// Everything that needs to know connectivity — [OfflineModeBanner],
/// [requireInternet], provider cache fallbacks — reads from here instead
/// of each keeping its own `connectivity_plus` subscription. That keeps
/// there being exactly one plugin listener alive, and one definition of
/// "online" the whole app agrees on.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  bool _isOnline = true; // optimistic default until the first check lands
  bool _initialized = false;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final _controller = StreamController<bool>.broadcast();

  /// Last-known online state — synchronous, safe to read from build().
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  /// Fires whenever online/offline state actually changes (not on every
  /// connectivity event — e.g. wifi-to-wifi doesn't re-fire this).
  Stream<bool> get onStatusChange => _controller.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (kIsWeb) {
      // Web builds don't run the Offline Materials System; connectivity
      // still resolves fine via the plugin, so no special-casing needed
      // beyond what's already guarded elsewhere by kIsWeb.
    }
    await _refresh(await Connectivity().checkConnectivity());
    _sub = Connectivity().onConnectivityChanged.listen(_refresh);
  }

  Future<void> _refresh(List<ConnectivityResult> results) async {
    final online = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
    if (online != _isOnline) {
      _isOnline = online;
      _controller.add(online);
    }
  }

  /// Forces an immediate re-check rather than waiting for the next event —
  /// used by "Retry" buttons on offline states.
  Future<bool> checkNow() async {
    await _refresh(await Connectivity().checkConnectivity());
    return _isOnline;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
