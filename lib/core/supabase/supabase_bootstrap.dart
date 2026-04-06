import 'package:supabase_flutter/supabase_flutter.dart';

/// Initializes Supabase for the app.
abstract final class SupabaseBootstrap {
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}
