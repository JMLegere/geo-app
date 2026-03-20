import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/state/app_database_provider.dart';
import 'package:earth_nova/core/species/drift_species_repository.dart';
import 'package:earth_nova/core/species/species_cache.dart';
import 'package:earth_nova/core/species/species_repository.dart';

/// Singleton repository provider for species data.
///
/// Backed by [DriftSpeciesRepository] which queries [LocalSpeciesTable]
/// in the main [AppDatabase]. Synchronous — no asset loading needed.
final speciesRepositoryProvider = Provider<SpeciesRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftSpeciesRepository(db);
});

/// Sync provider for [SpeciesCache], backed by [speciesRepositoryProvider].
///
/// Always returns a real cache — the repository is synchronously available.
final speciesCacheProvider = Provider<SpeciesCache>((ref) {
  final repo = ref.watch(speciesRepositoryProvider);
  return SpeciesCache(repo);
});
