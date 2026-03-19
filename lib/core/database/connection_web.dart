import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/wasm.dart';

/// Cache-busting version for the sqlite3.wasm file.
///
/// Bump this whenever the sqlite3 package is upgraded in pubspec.yaml.
/// Without it, browsers may serve a stale cached copy after deploys —
/// which caused a production outage when Git LFS replaced the binary
/// with a 131-byte pointer file and the browser kept serving the cached
/// pointer even after the fix was deployed.
const _wasmVersion = '2.9.4';

/// Creates a persistent SQLite database for web.
///
/// Strategy: try Drift's [WasmDatabase.open] first (web worker + OPFS).
/// If that hangs or fails (known issue without COOP/COEP headers — Drift
/// #3242), fall back to direct WASM loading with IndexedDB persistence.
///
/// Supabase is the source of truth — local data loss is acceptable.
QueryExecutor createDatabaseConnection() {
  return DatabaseConnection.delayed(
    Future(() async {
      // ── Attempt 1: WasmDatabase.open (worker + OPFS) ──────────────
      debugPrint('[connection_web] attempting WasmDatabase.open (worker)…');
      try {
        final result = await WasmDatabase.open(
          databaseName: 'earthnova',
          sqlite3Uri: Uri.parse('sqlite3.wasm?v=$_wasmVersion'),
          driftWorkerUri: Uri.parse('drift_worker.js'),
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
      debugPrint('[connection_web] loading sqlite3.wasm directly…');
      final sqlite3 = await WasmSqlite3.loadFromUrl(
        Uri.parse('sqlite3.wasm?v=$_wasmVersion'),
      );

      try {
        final fs = await IndexedDbFileSystem.open(dbName: 'earthnova_db');
        sqlite3.registerVirtualFileSystem(fs, makeDefault: true);
      } catch (e) {
        debugPrint(
          '[connection_web] IndexedDB unavailable ($e) '
          '— falling back to in-memory',
        );
        sqlite3.registerVirtualFileSystem(
          InMemoryFileSystem(),
          makeDefault: true,
        );
      }

      return DatabaseConnection(
        WasmDatabase(sqlite3: sqlite3, path: '/earthnova.db'),
      );
    }),
  );
}
