// lib/core/platform_init_web.dart
//
// Web stub implementation. Selected via the conditional import in
// main.dart when `dart.library.html` is available.
//
// dart:io (and therefore sqflite_common_ffi, which depends on dart:ffi)
// is not available on web, so this file must not import either — it
// mirrors platform_init_io.dart's public API as harmless no-ops instead.
// This matches the existing ai_provider_web.dart / sharing_service_web.dart
// stub pattern already used in this codebase.

bool get isWindowsDesktop => false;

/// No-op on web. `connectivity_service.dart` already documents in its own
/// comments that "web builds don't run the Offline Materials System" —
/// so there's nothing here for this platform to initialize.
Future<void> initDesktopSqliteIfNeeded() async {}
