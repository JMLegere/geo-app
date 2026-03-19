import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

/// Minimum set of tables that must exist for the app to function.
/// If any are missing after the integrity check passes, the database file
/// is deleted and Drift recreates from scratch via [onCreate] → [createAll].
const _expectedTables = [
  'local_cell_progress_table',
  'local_item_instance_table',
  'local_player_profile_table',
];

/// Creates a file-backed SQLite database for native platforms.
///
/// On first open, runs PRAGMA integrity_check. If the database is corrupt
/// or expected tables are missing, deletes the file and lets Drift recreate
/// from scratch — Supabase is the source of truth, so local data loss is
/// acceptable.
QueryExecutor createDatabaseConnection() {
  return LazyDatabase(() async {
    final file = File('earth_nova.db');

    // Check for corruption if the file already exists.
    if (file.existsSync()) {
      try {
        final db = raw.sqlite3.open(file.path);
        final result = db.select('PRAGMA integrity_check');
        final status = result.isNotEmpty
            ? result.first['integrity_check'] as String
            : 'unknown';

        if (status != 'ok') {
          db.dispose();
          debugPrint(
              '[connection_native] database corrupt ($status) — deleting');
          file.deleteSync();
        } else if (!_tablesExist(db)) {
          // Integrity check passed but tables are missing. This can happen
          // if a previous corruption recovery dropped tables without
          // resetting user_version — Drift then skips onCreate.
          final version = db.select('PRAGMA user_version').first.values.first;
          db.dispose();
          debugPrint(
            '[connection_native] tables missing '
            '(user_version=$version) — deleting',
          );
          file.deleteSync();
        } else {
          db.dispose();
        }
      } catch (e) {
        debugPrint(
            '[connection_native] integrity check failed ($e) — deleting');
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }

    return NativeDatabase(file);
  });
}

/// Returns true if all expected application tables exist in the database.
bool _tablesExist(raw.Database db) {
  try {
    final rows = db.select(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final existing = rows.map((r) => r['name'] as String).toSet();
    return _expectedTables.every(existing.contains);
  } catch (_) {
    return false;
  }
}
