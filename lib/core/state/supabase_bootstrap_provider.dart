import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/config/supabase_bootstrap.dart';

/// Provides the global [SupabaseBootstrap] instance.
///
/// Consumers `await ref.read(supabaseBootstrapProvider).ready` before
/// deciding which auth service to use. The [SupabaseBootstrap.initialize]
/// method is called from `main()` before `ProviderScope` is created, and the
/// pre-initialized instance is passed in via `overrideWithValue`.
///
/// This is a synchronous [Provider] — the class holds the initialization
/// future internally rather than exposing it as an async provider state.
final supabaseBootstrapProvider = Provider<SupabaseBootstrap>((ref) {
  return SupabaseBootstrap();
});
