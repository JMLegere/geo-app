import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/core/config/supabase_config.dart';

/// Handles Supabase SDK initialization at app startup.
///
/// Call [initialize] from `main()` before `runApp()`. Returns `true` when
/// Supabase is ready, `false` when credentials are absent or init fails.
/// [initialized] reflects the result so other providers can decide whether
/// to use Supabase-backed services.
class SupabaseBootstrap {
  static bool _initialized = false;

  /// Whether `Supabase.initialize()` completed successfully.
  ///
  /// Stable after [initialize] returns. When `false`, the app operates in
  /// offline-only mode regardless of whether credentials were supplied.
  static bool get initialized => _initialized;

  /// Initializes the Supabase SDK.
  ///
  /// Returns `true` on success, `false` when credentials are absent or
  /// initialization fails. Never throws.
  static Future<bool> initialize() async {
    if (SupabaseConfig.projectUrl.isEmpty) {
      debugPrint('[SupabaseBootstrap] no credentials — skipping init');
      return false;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.projectUrl,
        anonKey: SupabaseConfig.anonKey,
      );
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('[SupabaseBootstrap] initialization failed: $e');
      _initialized = false;
      return false;
    }
  }
}
