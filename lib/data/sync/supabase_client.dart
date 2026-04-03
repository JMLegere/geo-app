import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads Supabase credentials from `--dart-define` values.
class _SupabaseConfig {
  static const String projectUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
}

/// Handles Supabase SDK initialization at app startup.
///
/// Call [initialize] from `main()` before `runApp()`. Returns `true` when
/// Supabase is ready, `false` when credentials are absent or init fails.
/// [initialized] reflects the result so other providers can decide whether
/// to use Supabase-backed services.
class SupabaseBootstrap {
  static bool _initialized = false;

  /// Whether `Supabase.initialize()` completed successfully.
  static bool get initialized => _initialized;

  /// Returns the Supabase client if initialized, null otherwise.
  static SupabaseClient? get client =>
      _initialized ? Supabase.instance.client : null;

  /// Initializes the Supabase SDK.
  ///
  /// Returns `true` on success, `false` when credentials are absent or
  /// initialization fails. Never throws.
  static Future<bool> initialize() async {
    if (_SupabaseConfig.projectUrl.isEmpty) {
      debugPrint('[SupabaseBootstrap] no credentials — skipping init');
      return false;
    }

    try {
      await Supabase.initialize(
        url: _SupabaseConfig.projectUrl,
        anonKey: _SupabaseConfig.anonKey,
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
