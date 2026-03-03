import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fog_of_world/core/config/supabase_config.dart';

/// Initializes the Supabase SDK when credentials are available.
///
/// Does nothing when `SUPABASE_URL` / `SUPABASE_ANON_KEY` are not supplied
/// via `--dart-define`, allowing the app to run in offline-only mode with
/// `MockAuthService`.
Future<void> initializeSupabase() async {
  if (SupabaseConfig.projectUrl.isNotEmpty) {
    await Supabase.initialize(
      url: SupabaseConfig.projectUrl,
      anonKey: SupabaseConfig.anonKey,
    );
  }
}
