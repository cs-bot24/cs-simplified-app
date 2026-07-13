import 'dart:developer' as dev;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton wrapper around the app's local SQLite database.
///
/// This is the single source of truth for everything the Offline Materials
/// System needs to persist: which materials are downloaded, where their
/// files live, download-queue state (for resume/retry), offline bookmarks,
/// reading progress, and one-shot UI flags (e.g. "smart download" prompts
/// that must only be shown once per course).
///
/// Nothing outside `lib/services/offline/` and `lib/services/pdf/` should
/// import this file directly — always go through
/// `LocalMaterialRepository` / `OfflineMaterialService`.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const int _version = 2;
  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'offline_materials.db');
    dev.log('[AppDatabase] Opening $path', name: 'AppDatabase');
    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Downloaded / in-progress materials. One row per materialId.
    await db.execute('''
      CREATE TABLE offline_materials (
        material_id       INTEGER PRIMARY KEY,
        course_id         INTEGER,
        course_code       TEXT,
        category_name     TEXT,
        title             TEXT NOT NULL,
        file_url          TEXT NOT NULL,
        file_type         TEXT NOT NULL DEFAULT 'pdf',
        local_path        TEXT,
        file_size_bytes   INTEGER NOT NULL DEFAULT 0,
        file_hash         TEXT,
        server_version    TEXT,
        local_version     TEXT,
        status            TEXT NOT NULL DEFAULT 'not_downloaded',
        downloaded_at     TEXT,
        last_opened_at    TEXT,
        last_opened_page  INTEGER NOT NULL DEFAULT 0,
        page_count        INTEGER,
        reading_progress  REAL NOT NULL DEFAULT 0,
        is_favorite       INTEGER NOT NULL DEFAULT 0,
        ignored_version   TEXT
      )
    ''');

    // Active/queued/failed downloads. Kept separate from offline_materials
    // so a queued-but-not-yet-downloaded item doesn't need a fake row there.
    await db.execute('''
      CREATE TABLE download_queue (
        material_id     INTEGER PRIMARY KEY,
        title           TEXT NOT NULL,
        file_url        TEXT NOT NULL,
        course_id       INTEGER,
        course_code     TEXT,
        category_name   TEXT,
        file_type       TEXT NOT NULL DEFAULT 'pdf',
        status          TEXT NOT NULL DEFAULT 'queued',
        bytes_received  INTEGER NOT NULL DEFAULT 0,
        bytes_total     INTEGER NOT NULL DEFAULT 0,
        retry_count     INTEGER NOT NULL DEFAULT 0,
        added_at        TEXT NOT NULL,
        temp_path       TEXT
      )
    ''');

    // Offline-persisted bookmarks (page-level), independent of connectivity.
    await db.execute('''
      CREATE TABLE offline_bookmarks (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        material_id INTEGER NOT NULL,
        page        INTEGER NOT NULL,
        label       TEXT,
        created_at  TEXT NOT NULL,
        UNIQUE(material_id, page)
      )
    ''');

    // Tracks how many times a course has been opened, and whether the
    // "download this course for offline study?" nudge has already fired.
    await db.execute('''
      CREATE TABLE course_download_prompts (
        course_id   INTEGER PRIMARY KEY,
        open_count  INTEGER NOT NULL DEFAULT 0,
        prompted    INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Log of completed/failed downloads — the queue table only holds
    // *pending* work, so this is what backs the Download Queue screen's
    // "Completed" / "Failed" sections (and "Clear Completed").
    await db.execute('''
      CREATE TABLE download_history (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        material_id     INTEGER NOT NULL,
        title           TEXT NOT NULL,
        course_code     TEXT,
        status          TEXT NOT NULL,
        error           TEXT,
        file_size_bytes INTEGER NOT NULL DEFAULT 0,
        occurred_at     TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_offline_materials_course ON offline_materials(course_id)',
    );
    await db.execute(
      'CREATE INDEX idx_offline_bookmarks_material ON offline_bookmarks(material_id)',
    );
    await db.execute(
      'CREATE INDEX idx_download_history_time ON download_history(occurred_at)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE offline_materials ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE offline_materials ADD COLUMN ignored_version TEXT',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS download_history (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          material_id     INTEGER NOT NULL,
          title           TEXT NOT NULL,
          course_code     TEXT,
          status          TEXT NOT NULL,
          error           TEXT,
          file_size_bytes INTEGER NOT NULL DEFAULT 0,
          occurred_at     TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_download_history_time ON download_history(occurred_at)',
      );
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
