import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/domain/seed/daily_seed.dart';

// ---------------------------------------------------------------------------
// Supabase RPC fetcher (optional — wired by engine_provider if configured)
// ---------------------------------------------------------------------------

/// Injectable Supabase RPC caller for [DailySeedService].
///
/// Override in engine_provider.dart with a concrete Supabase RPC closure
/// when credentials are available. When null, [DailySeedService] uses
/// the offline fallback seed.
final dailySeedFetcherProvider = Provider<SeedFetcher?>((ref) => null);

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

/// The [DailySeedService] — created once, wired lazily by [engine_provider].
///
/// The Supabase RPC fetcher is injected after construction via
/// [dailySeedFetcherProvider] override in main.dart / engine_provider.
final dailySeedServiceProvider = Provider<DailySeedService>((ref) {
  final fetcher = ref.watch(dailySeedFetcherProvider);
  return DailySeedService(fetchRemoteSeed: fetcher);
});
