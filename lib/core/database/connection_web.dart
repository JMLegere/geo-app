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
  return DatabaseConnection.delayed(Future(() async {
    final sqlite3 = await WasmSqlite3.loadFromUrl(
      Uri.parse('sqlite3.wasm'),
    );

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

    final db = WasmDatabase(sqlite3: sqlite3, path: '/earthnova.db');
    return DatabaseConnection(db);
  }));
}
