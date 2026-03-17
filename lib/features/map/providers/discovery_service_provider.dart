import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/state/cell_service_provider.dart';
import 'package:earth_nova/core/state/daily_seed_provider.dart';
import 'package:earth_nova/core/state/fog_resolver_provider.dart';
import 'package:earth_nova/features/world/providers/habitat_service_provider.dart';
import 'package:earth_nova/features/discovery/providers/discovery_provider.dart';
import 'package:earth_nova/features/discovery/services/discovery_service.dart';
import 'package:earth_nova/features/calendar/providers/season_service_provider.dart';

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
/// ## Lazy Getter Pattern (species + habitat)
///
/// Both the species service and habitat service are resolved lazily at event
/// time via getter callbacks instead of `ref.watch()`. This is critical
/// because both depend on FutureProviders:
///
/// - `speciesServiceProvider` depends on `speciesDataProvider` (FutureProvider
///   that async-loads 32,752 IUCN records).
/// - `habitatServiceProvider` depends on `biomeFeatureIndexProvider`
///   (FutureProvider that async-loads biome feature data from bundled JSON).
///
/// If we `ref.watch`'d either, the entire provider chain
/// (DiscoveryService → GameCoordinator) would be torn down and rebuilt when
/// the async data finishes loading, losing all GPS subscriptions, visited
/// cell state, and auth session — causing a dark/broken map.
///
/// With `ref.read` + getter, the DiscoveryService is created once and reads
/// the latest service instances at the moment a cell is visited. During the
/// brief loading window, getters return fallback instances (empty
/// SpeciesService / plains-only HabitatService). Once loaded, they return
/// the full datasets.
final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final fogResolver = ref.watch(fogResolverProvider);
  final cellService = ref.watch(cellServiceProvider);
  final seasonService = ref.watch(seasonServiceProvider);
  final dailySeedService = ref.watch(dailySeedServiceProvider);

  // Read species + habitat services once for fallback, pass lazy getters for
  // event-time resolution. This breaks the rebuild chain: async data loading
  // does NOT invalidate this provider or its downstream
  // (gameCoordinatorProvider).
  final speciesService = ref.read(speciesServiceProvider);
  final habitatService = ref.read(habitatServiceProvider);

  final service = DiscoveryService(
    fogResolver: fogResolver,
    speciesService: speciesService,
    habitatService: habitatService,
    cellService: cellService,
    seasonService: seasonService,
    dailySeedService: dailySeedService,
    speciesServiceGetter: () => ref.read(speciesServiceProvider),
    habitatServiceGetter: () => ref.read(habitatServiceProvider),
  );
  ref.onDispose(() => service.dispose());
  return service;
});
