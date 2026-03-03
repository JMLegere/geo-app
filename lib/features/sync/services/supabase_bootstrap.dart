import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fog_of_world/core/config/supabase_config.dart';

/// Whether `Supabase.initialize()` completed successfully.
///
/// When `false`, the app operates in offline-only mode regardless of whether
/// credentials were supplied. Auth falls back to `MockAuthService`.
bool supabaseInitialized = false;

/// Initializes the Supabase SDK when credentials are available.
///
/// Does nothing when `SUPABASE_URL` / `SUPABASE_ANON_KEY` are not supplied
/// via `--dart-define`, allowing the app to run in offline-only mode with
/// `MockAuthService`.
Future<void> initializeSupabase() async {
  if (SupabaseConfig.projectUrl.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.projectUrl,
        anonKey: SupabaseConfig.anonKey,
      );
      supabaseInitialized = true;
    } catch (e) {
      // On web, Supabase init can fail with "invalid language tag: undefined"
      // when the browser doesn't expose a valid locale. The app falls back to
      // MockAuthService / offline mode in that case.
      debugPrint('[SupabaseBootstrap] initialization failed: $e');
      supabaseInitialized = false;
    }
  }
}
