import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import 'app_database.dart' show kExpectedTableNames;

/// No-op on native — database corruption is handled at connection open via
/// PRAGMA integrity_check. See [createDatabaseConnection].
void resetDatabaseStorage() {
  debugPrint('[connection_native] resetDatabaseStorage called — no-op');
}

/// Creates a file-backed SQLite database for native platforms.
///
/// On first open, runs PRAGMA integrity_check and verifies that expected
/// tables exist. If the database is corrupt or tables are missing, deletes
/// the file and lets Drift recreate from scratch — Supabase is the source
/// of truth, so local data loss is acceptable.
///
/// TODO(native-launch): Replace `File('earth_nova.db')` with
/// `path_provider`'s `getApplicationDocumentsDirectory()` before shipping
/// native builds. The relative path works in development and tests but is
/// unsafe on iOS/Android where the working directory is unpredictable.
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
    return kExpectedTableNames.every(existing.contains);
  } catch (_) {
    return false;
  }
}
