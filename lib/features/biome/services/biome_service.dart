import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/features/biome/models/esa_land_cover.dart';

/// Strategy interface for resolving a geographic coordinate to an ESA land
/// cover code.
///
/// Implement this to provide real GeoTIFF lookups, cached tile data, or any
/// other data source.
abstract interface class HabitatLookupStrategy {
  /// Returns the ESA WorldCover code for [lat]/[lon], or null if unknown.
  int? getEsaCode(double lat, double lon);
}

/// Default lookup strategy — no pre-loaded data.
///
/// [getEsaCode] always returns null, so [HabitatService.classifyLocation]
/// falls back to [Habitat.plains] for every coordinate.
class DefaultHabitatLookup implements HabitatLookupStrategy {
  const DefaultHabitatLookup();

  @override
  int? getEsaCode(double lat, double lon) => null;
}

/// Coordinate-grid lookup strategy backed by an in-memory map.
///
/// Coordinates are quantised to a ~1 km grid cell using
/// [CoordinateHabitatLookup.gridKey] before lookup, so small positional
/// variations within the same cell resolve to the same ESA code.
///
/// Usage:
/// ```dart
/// final lookup = CoordinateHabitatLookup();
/// lookup.loadRegionData({
///   CoordinateHabitatLookup.gridKey(51.5, -0.1): 10, // tree cover
/// });
/// final service = HabitatService(lookup: lookup);
/// ```
class CoordinateHabitatLookup implements HabitatLookupStrategy {
  final Map<String, int> _data = {};

  /// Returns the ~1 km resolution grid key for [lat]/[lon].
  ///
  /// Format: `"${(lat * 10).round()}_${(lon * 10).round()}"`
  static String gridKey(double lat, double lon) =>
      '${(lat * 10).round()}_${(lon * 10).round()}';

  /// Merges [data] (grid key → ESA code) into the internal lookup table.
  ///
  /// Call multiple times to incrementally load region tiles.
  void loadRegionData(Map<String, int> data) => _data.addAll(data);

  /// Returns the ESA code for [lat]/[lon], or null if the cell is absent.
  @override
  int? getEsaCode(double lat, double lon) => _data[gridKey(lat, lon)];
}

/// Classifies geographic coordinates into the seven game [Habitat]s.
///
/// Uses a pluggable [HabitatLookupStrategy] to resolve coordinates to ESA
/// WorldCover codes, then maps those codes to [Habitat] values via
/// [EsaLandCover.toHabitat].
///
/// When no data is available (strategy returns null or an unknown code is
/// supplied), [Habitat.plains] is returned as the most generic fallback.
class HabitatService {
  final HabitatLookupStrategy _lookup;

  /// Creates a [HabitatService].
  ///
  /// [lookup] defaults to [DefaultHabitatLookup] (plains fallback for every
  /// coordinate) when omitted.
  HabitatService({HabitatLookupStrategy? lookup})
      : _lookup = lookup ?? const DefaultHabitatLookup();

  /// Returns the [Habitat] for [lat]/[lon].
  ///
  /// Delegates to the configured [HabitatLookupStrategy] to obtain an ESA
  /// code, then maps it via [classifyFromEsaCode]. Returns [Habitat.plains]
  /// if the strategy has no data for the coordinate.
  Habitat classifyLocation(double lat, double lon) {
    final esaCode = _lookup.getEsaCode(lat, lon);
    if (esaCode == null) return Habitat.plains;
    return classifyFromEsaCode(esaCode);
  }

  /// Maps an ESA WorldCover [esaCode] to the corresponding [Habitat].
  ///
  /// Returns [Habitat.plains] for codes not present in [EsaLandCover].
  Habitat classifyFromEsaCode(int esaCode) {
    final landCover = EsaLandCover.fromCode(esaCode);
    return landCover?.toHabitat() ?? Habitat.plains;
  }
}

// ---------------------------------------------------------------------------
// Legacy type aliases — kept for a single migration cycle, then removed.
// ---------------------------------------------------------------------------

/// @deprecated Use [HabitatLookupStrategy].
typedef BiomeLookupStrategy = HabitatLookupStrategy;

/// @deprecated Use [DefaultHabitatLookup].
typedef DefaultBiomeLookup = DefaultHabitatLookup;

/// @deprecated Use [CoordinateHabitatLookup].
typedef CoordinateBiomeLookup = CoordinateHabitatLookup;

/// @deprecated Use [HabitatService].
typedef BiomeService = HabitatService;
