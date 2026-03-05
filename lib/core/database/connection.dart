// Platform-aware database connection factory.
//
// Uses Dart conditional imports to select the right backend:
// - Native (iOS, Android, desktop): NativeDatabase from dart:io
// - Web: in-memory NativeDatabase (no persistence across refreshes)
//
// When web persistence is needed, swap the web implementation for
// WasmDatabase from package:drift/wasm.dart.
export 'connection_native.dart'
    if (dart.library.js_interop) 'connection_web.dart';
