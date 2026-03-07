import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/core/state/cell_service_provider.dart';
import 'package:fog_of_world/core/state/daily_seed_provider.dart';
import 'package:fog_of_world/core/state/fog_resolver_provider.dart';
import 'package:fog_of_world/features/biome/providers/habitat_service_provider.dart';
import 'package:fog_of_world/features/discovery/providers/discovery_provider.dart';
import 'package:fog_of_world/features/discovery/services/discovery_service.dart';
import 'package:fog_of_world/features/seasonal/providers/season_service_provider.dart';

/// Provides the [DiscoveryService] that emits species encounters.
///
/// Subscribes to fog state changes and generates discovery events when the
/// player enters new cells. Real biome data is provided via
/// [habitatServiceProvider] and cell geometry via [cellServiceProvider].
/// Seasonal filtering is applied via [seasonServiceProvider] to ensure only
/// species available in the current season are encountered.
/// Daily seed rotation is provided via [dailySeedServiceProvider].
/// Disposed automatically when the provider is invalidated.
///
/// ## Species Service Resolution (lazy getter)
///
/// The species service is resolved lazily at event time via a getter callback
/// instead of `ref.watch(speciesServiceProvider)`. This is critical because
/// `speciesServiceProvider` depends on `speciesDataProvider` (FutureProvider
/// that async-loads 32,752 IUCN records). If we `ref.watch`'d it, the entire
/// provider chain (DiscoveryService → GameCoordinator) would be torn down and
/// rebuilt when species data finishes loading, losing all GPS subscriptions
/// and visited cell state.
///
/// With `ref.read` + getter, the DiscoveryService is created once and reads
/// the latest SpeciesService at the moment a cell is visited. During the
/// brief loading window, the getter returns an empty SpeciesService (no
/// encounters fire). Once loaded, it returns the full 32k dataset.
final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final fogResolver = ref.watch(fogResolverProvider);
  final habitatService = ref.watch(habitatServiceProvider);
  final cellService = ref.watch(cellServiceProvider);
  final seasonService = ref.watch(seasonServiceProvider);
  final dailySeedService = ref.watch(dailySeedServiceProvider);

  // Read species service once for fallback, pass lazy getter for event-time
  // resolution. This breaks the rebuild chain: species data loading does NOT
  // invalidate this provider or its downstream (gameCoordinatorProvider).
  final speciesService = ref.read(speciesServiceProvider);

  final service = DiscoveryService(
    fogResolver: fogResolver,
    speciesService: speciesService,
    habitatService: habitatService,
    cellService: cellService,
    seasonService: seasonService,
    dailySeedService: dailySeedService,
    speciesServiceGetter: () => ref.read(speciesServiceProvider),
  );
  ref.onDispose(() => service.dispose());
  return service;
});
