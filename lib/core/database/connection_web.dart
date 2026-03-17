import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/wasm.dart';

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
      try {
        final check = sqlite3.open('/earthnova.db');
        final result = check.select('PRAGMA integrity_check');
        final status = result.isNotEmpty
            ? result.first['integrity_check'] as String
            : 'unknown';
        check.dispose();
        if (status != 'ok') {
          debugPrint('[connection_web] database corrupt ($status) — wiping');
          _wipeDatabase(sqlite3);
        }
      } catch (e) {
        debugPrint('[connection_web] integrity check failed ($e) — wiping');
        _wipeDatabase(sqlite3);
      }

      final db = WasmDatabase(sqlite3: sqlite3, path: '/earthnova.db');
      return DatabaseConnection(db);
    }),
  );
}

void _wipeDatabase(CommonSqlite3 sqlite3) {
  try {
    final f = sqlite3.open('/earthnova.db');
    f.execute('PRAGMA journal_mode=DELETE');
    f.execute('DROP TABLE IF EXISTS local_cell_progress_table');
    f.execute('DROP TABLE IF EXISTS local_item_instance_table');
    f.execute('DROP TABLE IF EXISTS local_player_profile_table');
    f.execute('DROP TABLE IF EXISTS local_species_enrichment_table');
    f.execute('DROP TABLE IF EXISTS local_write_queue_table');
    f.execute('DROP TABLE IF EXISTS local_cell_properties_table');
    f.execute('DROP TABLE IF EXISTS local_location_node_table');
    f.execute('DROP TABLE IF EXISTS local_app_events_table');
    // Also drop Drift's internal tracking tables
    f.execute('DROP TABLE IF EXISTS _drift_database_version');
    f.execute('PRAGMA user_version = 0');
    f.dispose();
  } catch (_) {}
}
