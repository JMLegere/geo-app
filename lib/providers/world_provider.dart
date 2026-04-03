import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/domain/species/continent_resolver.dart';
import 'package:earth_nova/domain/world/biome_service.dart';
import 'package:earth_nova/domain/world/cell_property_resolver.dart';
import 'package:earth_nova/models/continent.dart';
import 'package:earth_nova/models/habitat.dart';

// ---------------------------------------------------------------------------
// Habitat lookup provider (injectable)
// ---------------------------------------------------------------------------

/// Injectable habitat lookup strategy for [HabitatService].
///
/// Override with a [CoordinateHabitatLookup] backed by loaded GeoTIFF data
/// when biome tile data is available. Default is [DefaultHabitatLookup]
/// which falls back to Plains for all coordinates.
final habitatLookupProvider = Provider<HabitatLookupStrategy>(
  (ref) => const DefaultHabitatLookup(),
);

// ---------------------------------------------------------------------------
// Cell property resolver
// ---------------------------------------------------------------------------

/// The [CellPropertyResolver] used by [GameEngine] to resolve geo-derived
/// cell properties (habitat, climate, continent).
///
/// Combines [HabitatService] (biome-based habitats) with [ContinentResolver]
/// (bounding-box continent detection).
final cellPropertyResolverProvider = Provider<CellPropertyResolver>((ref) {
  final habitatStrategy = ref.watch(habitatLookupProvider);
  return CellPropertyResolver(
    habitatLookup: _HabitatServiceAdapter(habitatStrategy),
    continentLookup: const _ContinentResolverAdapter(),
  );
});

// ---------------------------------------------------------------------------
// Adapters: domain interfaces → concrete implementations
// ---------------------------------------------------------------------------

class _HabitatServiceAdapter implements HabitatLookup {
  final HabitatLookupStrategy _strategy;
  _HabitatServiceAdapter(this._strategy);

  @override
  Set<Habitat> classifyLocation(double lat, double lon) {
    final service = HabitatService(lookup: _strategy);
    return service.classifyLocation(lat, lon);
  }
}

class _ContinentResolverAdapter implements ContinentLookup {
  const _ContinentResolverAdapter();

  @override
  Continent resolve(double lat, double lon) =>
      ContinentResolver.resolve(lat, lon);
}
