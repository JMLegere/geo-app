import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/cells/cell_property_resolver.dart';
import 'package:earth_nova/core/cells/country_resolver.dart';
import 'package:earth_nova/core/species/continent_resolver.dart';
import 'package:earth_nova/core/state/country_resolver_provider.dart';
import 'package:earth_nova/features/biome/providers/habitat_service_provider.dart';

/// Default [ContinentLookup] used while [CountryResolver] asset is loading.
///
/// Delegates to the legacy bounding-box [ContinentResolver] which is
/// synchronous and always available (no asset loading).
class _FallbackContinentLookup implements ContinentLookup {
  const _FallbackContinentLookup();

  @override
  resolve(double lat, double lon) => ContinentResolver.resolve(lat, lon);
}

/// Provides a [CellPropertyResolver] backed by real geographic data.
///
/// - **Habitat**: from [habitatServiceProvider] (BiomeFeatureIndex when ready,
///   plains fallback during loading).
/// - **Continent**: from [countryResolverProvider] (bundled Natural Earth
///   country boundaries when ready, bounding-box heuristic during loading).
/// - **Climate**: always from latitude math (synchronous, no data dependency).
final cellPropertyResolverProvider = Provider<CellPropertyResolver>((ref) {
  final habitatService = ref.watch(habitatServiceProvider);

  final countryResolverAsync = ref.watch(countryResolverProvider);
  final continentLookup = countryResolverAsync.when(
    data: (resolver) => resolver as ContinentLookup,
    loading: () => const _FallbackContinentLookup() as ContinentLookup,
    error: (_, __) => const _FallbackContinentLookup() as ContinentLookup,
  );

  return CellPropertyResolver(
    habitatLookup: habitatService,
    continentLookup: continentLookup,
  );
});
