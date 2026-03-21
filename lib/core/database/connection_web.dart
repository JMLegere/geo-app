import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/wasm.dart';
import 'package:web/web.dart' as web;

/// Cache-busting version for the sqlite3.wasm and drift_worker.js files.
///
/// Bump this whenever the sqlite3 or drift package is upgraded, or when
/// the database schema changes. Without it, browsers may serve a stale
/// cached copy after deploys — which caused a production outage when
/// the Drift worker didn't know about the new schema tables.
const _wasmVersion = '2.9.4-v19';

/// Creates a persistent SQLite database for web.
///
/// Strategy: try Drift's [WasmDatabase.open] first (web worker + OPFS).
/// If that hangs or fails (known issue without COOP/COEP headers — Drift
/// #3242), fall back to direct WASM loading with IndexedDB persistence.
///
/// On corruption (FormatException, SqliteException during migration),
/// wipes IndexedDB and retries with a fresh database. Supabase is the
/// source of truth — local data loss is acceptable.
QueryExecutor createDatabaseConnection() {
  return DatabaseConnection.delayed(
    Future(() async {
      // ── Attempt 1: WasmDatabase.open (worker + OPFS) ──────────────
      debugPrint('[connection_web] attempting WasmDatabase.open (worker)…');
      try {
        final result = await WasmDatabase.open(
          databaseName: 'earthnova',
          sqlite3Uri: Uri.parse('sqlite3.wasm?v=$_wasmVersion'),
          driftWorkerUri: Uri.parse('drift_worker.js?v=$_wasmVersion'),
        ).timeout(const Duration(seconds: 8));

        debugPrint(
          '[connection_web] storage: ${result.chosenImplementation}'
          '${result.missingFeatures.isNotEmpty ? ' (missing: ${result.missingFeatures})' : ''}',
        );

        return result.resolvedExecutor;
      } catch (e) {
        debugPrint(
          '[connection_web] WasmDatabase.open failed ($e) '
          '— falling back to direct IndexedDB',
        );
      }

      // ── Attempt 2: Direct WASM + IndexedDB (no worker) ───────────
      return _openDirectIndexedDb();
    }),
  );
}

Future<DatabaseConnection> _openDirectIndexedDb({bool isRetry = false}) async {
  debugPrint('[connection_web] loading sqlite3.wasm directly…');
  final sqlite3 = await WasmSqlite3.loadFromUrl(
    Uri.parse('sqlite3.wasm?v=$_wasmVersion'),
  );

  try {
    final fs = await IndexedDbFileSystem.open(dbName: 'earthnova_db');
    sqlite3.registerVirtualFileSystem(fs, makeDefault: true);
  } catch (e) {
    if (!isRetry) {
      // Corrupt IndexedDB — wipe and retry once.
      // ignore: avoid_print
      print(
        '[RECOVERY] IndexedDB corrupt ($e) — wiping earthnova_db and retrying. '
        'Supabase is source of truth — no data loss.',
      );
      await _deleteIndexedDb('earthnova_db');
      return await _openDirectIndexedDb(isRetry: true);
    }
    // ignore: avoid_print
    print(
      '[RECOVERY] IndexedDB unavailable after retry ($e) '
      '— falling back to in-memory. All data will be lost on refresh.',
    );
    sqlite3.registerVirtualFileSystem(
      InMemoryFileSystem(),
      makeDefault: true,
    );
  }

  return DatabaseConnection(
    WasmDatabase(sqlite3: sqlite3, path: '/earthnova.db'),
  );
}

/// Delete an IndexedDB database by name to recover from corruption.
Future<void> _deleteIndexedDb(String name) async {
  try {
    final factory = web.window.self.indexedDB;
    factory.deleteDatabase(name);
    debugPrint('[connection_web] deleted IndexedDB "$name"');
  } catch (e) {
    debugPrint('[connection_web] failed to delete IndexedDB "$name": $e');
  }
}
