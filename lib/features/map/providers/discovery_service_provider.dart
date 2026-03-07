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
final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final fogResolver = ref.watch(fogResolverProvider);
  final speciesService = ref.watch(speciesServiceProvider);
  final habitatService = ref.watch(habitatServiceProvider);
  final cellService = ref.watch(cellServiceProvider);
  final seasonService = ref.watch(seasonServiceProvider);
  final dailySeedService = ref.watch(dailySeedServiceProvider);
  final service = DiscoveryService(
    fogResolver: fogResolver,
    speciesService: speciesService,
    habitatService: habitatService,
    cellService: cellService,
    seasonService: seasonService,
    dailySeedService: dailySeedService,
  );
  ref.onDispose(() => service.dispose());
  return service;
});
