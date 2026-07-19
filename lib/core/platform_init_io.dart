// lib/core/platform_init_io.dart
//
// Non-web platform implementation (Android/iOS/macOS/Windows/Linux).
// Selected via the conditional import in main.dart:
//   import 'core/platform_init_io.dart'
//       if (dart.library.html) 'core/platform_init_web.dart';
// — the same pattern already used by ai_provider.dart and
// sharing_service.dart for their _io/_web split.
//
// Desktop audit reference: Part 6 (Database Audit) / Part 15 (Architecture).
// Implementation phase: Phase 1 (SQLite Windows Support).

import 'dart:io' show Platform;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// True only on a native Windows build (never true on web — this file
/// isn't compiled into the web bundle at all, see the conditional import
/// above — and never true on Android/iOS/macOS).
bool get isWindowsDesktop => Platform.isWindows;

/// Must be awaited before the first access to `AppDatabase.instance.database`
/// (see lib/core/database/app_database.dart). Call this once, early in
/// `main()`, right after `WidgetsFlutterBinding.ensureInitialized()`.
///
/// Why this is needed: sqflite's native plugin implementation only ships
/// Android/iOS/macOS backends. On Windows there is no native sqflite
/// implementation at all — `AppDatabase.database` would throw
/// `MissingPluginException` without this. `sqflite_common_ffi` provides an
/// FFI-based SQLite engine and installs itself by replacing sqflite's
/// global `databaseFactory` — every existing `openDatabase()`,
/// `db.query()`, `db.insert()`, `db.execute()` call in AppDatabase and the
/// offline repositories keeps working completely unchanged, because they
/// all go through that same global factory. This function does not, and
/// must not, touch:
///   - table definitions / schema (app_database.dart _onCreate)
///   - migrations (app_database.dart _onUpgrade)
///   - any query in local_material_repository.dart or elsewhere
///
/// Linux is intentionally NOT handled here yet. The desktop audit (Part 2)
/// flagged `pdfx`'s Linux support as unverified on pub.dev, so Linux is not
/// an enabled target for this phase. Once that's verified, Linux support
/// is a one-line addition: `Platform.isWindows || Platform.isLinux`.
Future<void> initDesktopSqliteIfNeeded() async {
  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // Android / iOS / macOS: sqflite's native plugin already handles these —
  // deliberately left untouched, per the audit's "do not replace working
  // cross-platform systems unnecessarily" instruction.
}
