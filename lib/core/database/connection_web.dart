import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';

/// Cache-busting version for the sqlite3.wasm file.
///
/// Bump this whenever the sqlite3 package is upgraded in pubspec.yaml.
/// Without it, browsers may serve a stale cached copy after deploys —
/// which caused a production outage when Git LFS replaced the binary
/// with a 131-byte pointer file and the browser kept serving the cached
/// pointer even after the fix was deployed.
const _wasmVersion = '2.9.4';

/// Creates a persistent SQLite database for web via Drift's built-in
/// [WasmDatabase.open].
///
/// Drift probes browser capabilities and picks the best storage backend:
///   OPFS (shared locks) > OPFS (simple) > IndexedDB (shared worker)
///   > IndexedDB (unsafe) > in-memory.
///
/// Requires two files in the `web/` directory:
///   - `sqlite3.wasm` — from https://github.com/simolus3/sqlite3.dart/releases
///   - `drift_worker.js` — from https://github.com/simolus3/drift/releases
///
/// Supabase is the source of truth — local data loss is acceptable,
/// so we let Drift handle storage, corruption, and fallbacks instead
/// of writing custom integrity checks.
QueryExecutor createDatabaseConnection() {
  return DatabaseConnection.delayed(
    Future(() async {
      final result = await WasmDatabase.open(
        databaseName: 'earthnova',
        sqlite3Uri: Uri.parse('sqlite3.wasm?v=$_wasmVersion'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
      );

      if (result.missingFeatures.isNotEmpty) {
        debugPrint(
          '[connection_web] using ${result.chosenImplementation} '
          '(missing: ${result.missingFeatures})',
        );
      } else {
        debugPrint(
          '[connection_web] storage: ${result.chosenImplementation}',
        );
      }

      return result.resolvedExecutor;
    }),
  );
}
