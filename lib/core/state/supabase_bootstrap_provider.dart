import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/config/supabase_bootstrap.dart';

/// Whether Supabase initialized successfully.
///
/// Returns [SupabaseBootstrap.initialized] — a static flag set by
/// `main()` before `ProviderScope` is created. Stable for the lifetime of
/// the app (never changes at runtime).
///
/// Consumers use this to decide whether Supabase-backed services are
/// available. `false` means the app operates in offline-only mode.
final supabaseBootstrapProvider = Provider<bool>((ref) {
  return SupabaseBootstrap.initialized;
});
