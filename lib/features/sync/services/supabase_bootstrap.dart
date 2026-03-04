import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fog_of_world/core/config/supabase_config.dart';

/// Whether `Supabase.initialize()` completed successfully.
///
/// When `false`, the app operates in offline-only mode regardless of whether
/// credentials were supplied. Auth falls back to `MockAuthService`.
bool supabaseInitialized = false;

/// Completes when Supabase SDK initialization finishes (success or failure).
///
/// Consumers (e.g. `AuthNotifier`) `await supabaseReady` before deciding
/// whether to use `SupabaseAuthService` or `MockAuthService`. This allows
/// `main()` to call [initializeSupabase] without awaiting it — the UI
/// renders immediately while the SDK initializes in the background.
///
/// Defaults to a resolved future so the app (and tests) work even if
/// [initializeSupabase] is never called — auth falls back to
/// `MockAuthService` in that case.
Future<void> supabaseReady = Future<void>.value();

/// Maximum time to spend waiting for Supabase to initialize before falling
/// back to offline mode. Prevents slow networks from blocking app startup.
const _kSupabaseInitTimeout = Duration(seconds: 3);

/// Kicks off Supabase SDK initialization without blocking.
///
/// Sets [supabaseReady] to a future that resolves when init completes.
/// Does nothing when `SUPABASE_URL` / `SUPABASE_ANON_KEY` are not supplied
/// via `--dart-define`, allowing the app to run in offline-only mode with
/// `MockAuthService`.
void initializeSupabase() {
  if (SupabaseConfig.projectUrl.isNotEmpty) {
    supabaseReady = _doInitialize();
  } else {
    supabaseReady = Future<void>.value();
  }
}

Future<void> _doInitialize() async {
  try {
    await Supabase.initialize(
      url: SupabaseConfig.projectUrl,
      anonKey: SupabaseConfig.anonKey,
    ).timeout(_kSupabaseInitTimeout);
    supabaseInitialized = true;
  } on TimeoutException {
    debugPrint('[SupabaseBootstrap] initialization timed out after '
        '${_kSupabaseInitTimeout.inSeconds}s — continuing in offline mode');
    supabaseInitialized = false;
  } catch (e) {
    // On web, Supabase init can fail with "invalid language tag: undefined"
    // when the browser doesn't expose a valid locale. The app falls back to
    // MockAuthService / offline mode in that case.
    debugPrint('[SupabaseBootstrap] initialization failed: $e');
    supabaseInitialized = false;
  }
}
