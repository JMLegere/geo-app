import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/core/services/daily_seed_service.dart';
import 'package:earth_nova/core/state/supabase_bootstrap_provider.dart';

/// Provides a [DailySeedService] singleton.
///
/// Reads the Supabase bootstrap state to determine whether the SDK is
/// initialized. When configured, injects a [SeedFetcher] callback that
/// calls the `ensure_daily_seed()` Supabase RPC. When not configured,
/// the service uses an offline fallback seed.
final dailySeedServiceProvider = Provider<DailySeedService>((ref) {
  final bootstrap = ref.watch(supabaseBootstrapProvider);

  SeedFetcher? fetcher;
  if (bootstrap.initialized) {
    try {
      final client = Supabase.instance.client;
      fetcher = () async {
        final response = await client.rpc('ensure_daily_seed');
        return response as String;
      };
    } catch (_) {
      // Supabase instance not available — offline mode.
      fetcher = null;
    }
  }

  return DailySeedService(fetchRemoteSeed: fetcher);
});
