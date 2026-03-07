import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

/// Creates an in-memory SQLite database for web via WebAssembly.
///
/// Loads sqlite3.wasm from the web/ directory, registers an in-memory
/// virtual filesystem, and returns a WasmDatabase. Data does not persist
/// across page refreshes — Supabase is the source of truth.
QueryExecutor createDatabaseConnection() {
  return DatabaseConnection.delayed(Future(() async {
    final sqlite3 = await WasmSqlite3.loadFromUrl(
      Uri.parse('sqlite3.wasm'),
    );
    sqlite3.registerVirtualFileSystem(
      InMemoryFileSystem(),
      makeDefault: true,
    );
    final db = WasmDatabase.inMemory(sqlite3);
    return DatabaseConnection(db);
  }));
}
