import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

/// Creates a file-backed SQLite database for native platforms.
///
/// On first open, runs PRAGMA integrity_check. If the database is corrupt,
/// deletes the file and lets Drift recreate from scratch — Supabase is the
/// source of truth, so local data loss is acceptable.
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
        db.dispose();

        if (status != 'ok') {
          debugPrint(
              '[connection_native] database corrupt ($status) — deleting');
          file.deleteSync();
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
