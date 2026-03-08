import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/core/config/supabase_config.dart';

/// Maximum time to spend waiting for Supabase to initialize before falling
/// back to offline mode. Prevents slow networks from blocking app startup.
const _kSupabaseInitTimeout = Duration(seconds: 3);

/// Encapsulates Supabase SDK initialization state.
///
/// Consumers (e.g. `gameCoordinatorProvider`) `await bootstrap.ready` before
/// deciding whether to use `SupabaseAuthService` or `MockAuthService`. This
/// allows `main()` to call [initialize] without awaiting it — the UI renders
/// immediately while the SDK initializes in the background.
///
/// Default state (`initialized = false`, `ready` already resolved) means
/// the app (and tests) work correctly even if [initialize] is never called —
/// auth falls back to `MockAuthService` in that case.
class SupabaseBootstrap {
  bool _initialized = false;
  Future<void> _ready = Future<void>.value();

  /// Whether `Supabase.initialize()` completed successfully.
  ///
  /// When `false`, the app operates in offline-only mode regardless of whether
  /// credentials were supplied. Auth falls back to `MockAuthService`.
  bool get initialized => _initialized;

  /// Completes when Supabase SDK initialization finishes (success or failure).
  ///
  /// Already resolved on construction so the app works in offline-only mode
  /// without ever calling [initialize].
  Future<void> get ready => _ready;

  /// Kicks off Supabase SDK initialization without blocking.
  ///
  /// Sets [ready] to a future that resolves when init completes.
  /// Does nothing meaningful when `SUPABASE_URL` / `SUPABASE_ANON_KEY` are
  /// not supplied via `--dart-define`, allowing the app to run in
  /// offline-only mode with `MockAuthService`.
  void initialize() {
    if (SupabaseConfig.projectUrl.isNotEmpty) {
      _ready = _doInitialize();
    } else {
      _ready = Future<void>.value();
    }
  }

  Future<void> _doInitialize() async {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.projectUrl,
        anonKey: SupabaseConfig.anonKey,
      ).timeout(_kSupabaseInitTimeout);
      _initialized = true;
    } on TimeoutException {
      debugPrint('[SupabaseBootstrap] initialization timed out after '
          '${_kSupabaseInitTimeout.inSeconds}s — continuing in offline mode');
      _initialized = false;
    } catch (e) {
      // On web, Supabase init can fail with "invalid language tag: undefined"
      // when the browser doesn't expose a valid locale. The app falls back to
      // MockAuthService / offline mode in that case.
      debugPrint('[SupabaseBootstrap] initialization failed: $e');
      _initialized = false;
    }
  }
}
