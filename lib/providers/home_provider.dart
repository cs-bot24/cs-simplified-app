import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../models/home_model.dart';

/// Manages all data for the home screen ecosystem:
///   • Aggregated home payload (streak, quote, trending, recently viewed, exam count)
///   • Streak ping on app launch
///   • Stale-while-revalidate cache using SharedPreferences
///
/// Caching strategy:
///   On first load (or after cache expiry) → show shimmer, fetch fresh data.
///   On subsequent loads with valid cache → show cached data instantly, then
///   silently fetch fresh data and update UI when it arrives.
///   This makes the home screen feel instant on every visit after the first.
///
/// Registration: HomeProvider must be registered in main.dart's MultiProvider
/// so the streak ping can be called once at app startup regardless of which
/// screen the user is on.
class HomeProvider extends ChangeNotifier {
  HomeData? _data;
  bool _loading = false;
  String? _error;

  // Cache settings
  static const _cacheKey      = 'home_cache_v1';
  static const _cacheTimeKey  = 'home_cache_time_v1';
  static const _cacheMaxAge   = Duration(minutes: 30);

  // Streak ping deduplication — prevent multiple pings within a short window.
  // The home screen calls pingStreak() on initState AND on resume; without
  // this guard, rapid foreground/background transitions and widget rebuilds
  // can fire multiple pings within seconds.
  DateTime? _lastStreakPingAt;
  static const _kStreakPingCooldown = Duration(minutes: 5);

  HomeData? get data    => _data;
  bool      get loading => _loading;
  String?   get error   => _error;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Fetch the aggregated home payload.
  ///
  /// Flow:
  ///  1. If no in-memory data yet, try loading from SharedPreferences cache.
  ///     If valid cache exists, show it immediately (instant first paint).
  ///  2. Fetch fresh data from the backend in the background.
  ///  3. On success, replace data and save new cache.
  ///  4. On error, keep showing cached/stale data if available;
  ///     only surface an error when there is absolutely nothing to show.
  Future<void> fetchHome({bool forceRefresh = false}) async {
    if (_loading) return;

    // Step 1 — serve from cache for instant display
    if (_data == null || forceRefresh) {
      await _loadFromCache();
    }

    _loading = true;
    // Only trigger a full shimmer rebuild when we have nothing to show yet.
    if (_data == null) notifyListeners();

    try {
      final raw  = await ApiClient.getHome();
      _data  = HomeData.fromJson(raw as Map<String, dynamic>);
      _error = null;
      _saveToCache(raw as Map<String, dynamic>); // fire-and-forget
    } on ApiException catch (e) {
      dev.log('[Home] Fetch error: ${e.message}', name: 'HomeProvider');
      // Only expose the error if we have nothing to show
      if (_data == null) _error = e.message;
    } catch (e) {
      dev.log('[Home] Unexpected error: $e', name: 'HomeProvider');
      if (_data == null) _error = 'Could not load home data.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Called fire-and-forget on every app launch and foreground resume.
  /// Deduplicates: if called within _kStreakPingCooldown of the last ping,
  /// it silently no-ops. This prevents spam when the home screen rebuilds,
  /// the app rapidly foregrounds/backgrounds, or multiple widgets call this.
  Future<void> pingStreak() async {
    final now = DateTime.now();
    if (_lastStreakPingAt != null &&
        now.difference(_lastStreakPingAt!) < _kStreakPingCooldown) {
      dev.log('[Home] Streak ping skipped (cooldown active)', name: 'HomeProvider');
      return;
    }
    _lastStreakPingAt = now;
    try {
      final updated = await ApiClient.pingStreak();
      if (_data != null) {
        _data = _data!.copyWithStreak(
          StreakModel.fromJson(updated as Map<String, dynamic>),
        );
        notifyListeners();
      }
    } catch (e) {
      dev.log('[Home] Streak ping silent error: $e', name: 'HomeProvider');
    }
  }

  // ── Cache helpers ──────────────────────────────────────────────────────────

  Future<void> _loadFromCache() async {
    try {
      final prefs      = await SharedPreferences.getInstance();
      final cached     = prefs.getString(_cacheKey);
      final cachedTime = prefs.getInt(_cacheTimeKey) ?? 0;

      if (cached == null) return;

      final age = DateTime.now().millisecondsSinceEpoch - cachedTime;
      if (age > _cacheMaxAge.inMilliseconds) return; // cache expired

      _data = HomeData.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
      );
      // Don't notifyListeners here — caller controls when to rebuild
    } catch (e) {
      dev.log('[Home] Cache read error: $e', name: 'HomeProvider');
    }
  }

  Future<void> _saveToCache(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data));
      await prefs.setInt(
        _cacheTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      dev.log('[Home] Cache write error: $e', name: 'HomeProvider');
    }
  }
}
