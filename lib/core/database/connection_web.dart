import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/wasm.dart';

/// Expected application tables. Used to verify the schema is intact after
/// the integrity check passes (catches user_version=14-but-no-tables state).
const _expectedTables = [
  'local_cell_progress_table',
  'local_item_instance_table',
  'local_player_profile_table',
  'local_species_enrichment_table',
  'local_write_queue_table',
  'local_cell_properties_table',
  'local_location_node_table',
  'local_app_events_table',
];

/// Creates a persistent SQLite database for web via WebAssembly + IndexedDB.
///
/// Loads sqlite3.wasm from the web/ directory, registers an IndexedDB-backed
/// virtual filesystem for persistence across page refreshes. Falls back to
/// in-memory if IndexedDB init fails (e.g. private browsing restrictions).
///
/// Supabase remains the source of truth — this local cache survives refreshes
/// so the app doesn't need to re-hydrate from the server on every page load.
QueryExecutor createDatabaseConnection() {
  return DatabaseConnection.delayed(
    Future(() async {
      final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));

      try {
        final fs = await IndexedDbFileSystem.open(dbName: 'earthnova_db');
        sqlite3.registerVirtualFileSystem(fs, makeDefault: true);
      } catch (e) {
        // IndexedDB unavailable (private browsing, quota exceeded, etc.)
        // Fall back to in-memory — data won't persist but app still works.
        debugPrint(
          '[connection_web] IndexedDB unavailable, falling back to '
          'in-memory: $e',
        );
        sqlite3.registerVirtualFileSystem(
          InMemoryFileSystem(),
          makeDefault: true,
        );
      }

      // Check for corruption from prior crashes (concurrent IndexedDB writes
      // can leave a partially-written SQLite file). If corrupted, wipe and
      // start fresh — Supabase is the source of truth.
      var needsWipe = false;
      try {
        final check = sqlite3.open('/earthnova.db');
        final result = check.select('PRAGMA integrity_check');
        final status = result.isNotEmpty
            ? result.first['integrity_check'] as String
            : 'unknown';
        if (status != 'ok') {
          debugPrint('[connection_web] database corrupt ($status) — wiping');
          needsWipe = true;
        } else if (!_tablesExist(check)) {
          // Integrity check passed but tables are missing. This happens when
          // a previous wipe dropped tables but failed to reset user_version
          // (the old code had a single try/catch that swallowed errors).
          // Drift sees user_version=14 → skips onCreate → all queries fail.
          debugPrint(
            '[connection_web] tables missing (user_version='
            '${check.select('PRAGMA user_version').first.values.first})'
            ' — wiping',
          );
          needsWipe = true;
        }
        check.dispose();
      } catch (e) {
        debugPrint('[connection_web] integrity check failed ($e) — wiping');
        needsWipe = true;
      }

      if (needsWipe) {
        _wipeDatabase(sqlite3);
      }

      final db = WasmDatabase(sqlite3: sqlite3, path: '/earthnova.db');
      return DatabaseConnection(db);
    }),
  );
}

/// Returns true if all expected application tables exist in the database.
bool _tablesExist(CommonDatabase db) {
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

/// Drops all application tables and resets the schema version so Drift
/// runs [onCreate] → [createAll] on next open.
///
/// Critical: reset user_version FIRST. If a subsequent DROP fails, Drift
/// will still see version 0 on next open and recreate everything. The old
/// code ran all statements in one try/catch — if any threw, user_version
/// stayed at 14 and Drift skipped migrations, leaving the DB table-less.
void _wipeDatabase(CommonSqlite3 sqlite3) {
  CommonDatabase? f;
  try {
    f = sqlite3.open('/earthnova.db');

    // Reset version FIRST — this is the critical statement. Even if every
    // DROP below fails, Drift will see version 0 and recreate all tables.
    f.execute('PRAGMA user_version = 0');

    f.execute('PRAGMA journal_mode=DELETE');

    // Drop each table independently so one failure doesn't skip the rest.
    for (final table in _expectedTables) {
      try {
        f.execute('DROP TABLE IF EXISTS $table');
      } catch (e) {
        debugPrint('[connection_web] failed to drop $table: $e');
      }
    }

    // Drop Drift's internal tracking table (if it exists).
    try {
      f.execute('DROP TABLE IF EXISTS _drift_database_version');
    } catch (e) {
      debugPrint('[connection_web] failed to drop _drift_database_version: $e');
    }
  } catch (e) {
    debugPrint('[connection_web] wipe failed: $e');
  } finally {
    f?.dispose();
  }
}
