import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/species/species_cache.dart';
import 'package:earth_nova/core/species/species_repository.dart';

/// Async provider that opens [SpeciesRepository] from `assets/species.db`.
///
/// Resolves once the DB bytes have been written to a temp file and the
/// connection is ready. Automatically disposes the DB on provider teardown.
final speciesRepositoryProvider =
    FutureProvider<SpeciesRepository>((ref) async {
  final repo = await SpeciesRepository.fromAssets();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Sync provider for [SpeciesCache], backed by [speciesRepositoryProvider].
///
/// Returns [SpeciesCache.empty()] while the repository is still loading
/// (AsyncLoading or AsyncError state), so callers never receive null.
/// Once the repository resolves the provider rebuilds with a real cache.
final speciesCacheProvider = Provider<SpeciesCache>((ref) {
  return ref.watch(speciesRepositoryProvider).when(
        data: (repo) => SpeciesCache(repo),
        loading: SpeciesCache.empty,
        error: (_, __) => SpeciesCache.empty(),
      );
});
