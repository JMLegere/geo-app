import 'package:earth_nova/models/cell_properties.dart';
import 'package:earth_nova/models/climate.dart';
import 'package:earth_nova/models/continent.dart';
import 'package:earth_nova/models/habitat.dart';

/// Strategy for resolving a coordinate to a continent.
///
/// Current implementation: [ContinentResolver] (bounding-box heuristics).
/// Future: [CountryResolver] (bundled country boundary polygons).
abstract interface class ContinentLookup {
  Continent resolve(double lat, double lon);
}

/// Strategy for resolving a coordinate to a set of habitats.
///
/// Implementation: [HabitatService] from features/biome.
abstract interface class HabitatLookup {
  Set<Habitat> classifyLocation(double lat, double lon);
}

/// Resolves permanent geo-derived properties for a Voronoi cell.
///
/// All operations are instant and offline-capable:
/// - Habitat: from BiomeFeatureIndex spatial queries
/// - Climate: from latitude math
/// - Continent: from country boundaries (or bounding-box fallback)
///
/// Location (state/city/district) is NOT resolved here — it's backfilled
/// async via Nominatim through a Supabase Edge Function.
///
/// Events (rotating layer) are NOT resolved here — use [EventResolver].
class CellPropertyResolver {
  final HabitatLookup _habitatLookup;
  final ContinentLookup _continentLookup;

  CellPropertyResolver({
    required HabitatLookup habitatLookup,
    required ContinentLookup continentLookup,
  })  : _habitatLookup = habitatLookup,
        _continentLookup = continentLookup;

  /// Resolve permanent properties for a cell. Instant, no network.
  ///
  /// [cellId] is the Voronoi cell identifier.
  /// [lat], [lon] are the cell center coordinates.
  ///
  /// Returns [CellProperties] with:
  /// - habitats: 1+ habitats (Plains fallback if nothing matches)
  /// - climate: from latitude
  /// - continent: from country boundaries or bounding-box heuristic
  /// - locationId: null (backfilled async by location enrichment)
  CellProperties resolve({
    required String cellId,
    required double lat,
    required double lon,
  }) {
    var habitats = _habitatLookup.classifyLocation(lat, lon);
    if (habitats.isEmpty) {
      habitats = {Habitat.plains};
    }

    final climate = Climate.fromLatitude(lat);
    final continent = _continentLookup.resolve(lat, lon);

    return CellProperties(
      cellId: cellId,
      habitats: habitats,
      climate: climate,
      continent: continent,
      locationId: null,
      createdAt: DateTime.now(),
    );
  }
}
