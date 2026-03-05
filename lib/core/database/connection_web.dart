import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Creates an in-memory SQLite database for web.
///
/// Data does not persist across page refreshes — suitable for development
/// and testing. For production web persistence, replace with `WasmDatabase`
/// from `package:drift/wasm.dart` and serve `sqlite3.wasm` + `drift_worker.js`.
QueryExecutor createDatabaseConnection() {
  return NativeDatabase.memory();
}
