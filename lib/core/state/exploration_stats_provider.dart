import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/models/hierarchy.dart';
import 'package:earth_nova/core/state/cell_service_provider.dart';
import 'package:earth_nova/core/state/fog_resolver_provider.dart';
import 'package:earth_nova/core/state/hierarchy_repository_provider.dart';
import 'package:earth_nova/features/items/providers/items_provider.dart';

/// Per-region exploration statistics.
class ExplorationStats {
  final int cellsExplored;
  final int cellsTotal;
  final int speciesFound;

  const ExplorationStats({
    this.cellsExplored = 0,
    this.cellsTotal = 0,
    this.speciesFound = 0,
  });

  double get percent => cellsTotal > 0 ? cellsExplored / cellsTotal : 0.0;

  ExplorationStats operator +(ExplorationStats other) => ExplorationStats(
        cellsExplored: cellsExplored + other.cellsExplored,
        cellsTotal: cellsTotal + other.cellsTotal,
        speciesFound: speciesFound + other.speciesFound,
      );
}

/// Computes exploration stats keyed by region ID (district, city, state, country).
///
/// Assigns each visited cell to its nearest district centroid, then aggregates
/// up the hierarchy: city = sum of districts, state = sum of cities, etc.
///
/// Returns empty map when no hierarchy data is available.
final explorationStatsProvider =
    FutureProvider<Map<String, ExplorationStats>>((ref) async {
  final fogResolver = ref.watch(fogResolverProvider);
  final visitedCellIds = fogResolver.visitedCellIds;
  final cellService = ref.watch(cellServiceProvider);
  final repo = ref.read(hierarchyRepositoryProvider);

  // Species count (total unique species found by the player).
  int totalSpecies = 0;
  try {
    totalSpecies = ref.watch(itemsProvider).uniqueDefinitionIds.length;
  } catch (_) {
    // itemsProvider may not be initialized yet.
  }

  // Load full hierarchy.
  final countries = await repo.getAllCountries();
  if (countries.isEmpty) return const {};

  // Collect ALL districts with their parent chain.
  final allDistricts = <HDistrict>[];
  final districtToCity = <String, String>{}; // districtId → cityId
  final cityToState = <String, String>{}; // cityId → stateId
  final stateToCountry = <String, String>{}; // stateId → countryId

  for (final country in countries) {
    final states = await repo.getStatesForCountry(country.id);
    for (final state in states) {
      stateToCountry[state.id] = country.id;
      final cities = await repo.getCitiesForState(state.id);
      for (final city in cities) {
        cityToState[city.id] = state.id;
        final districts = await repo.getDistrictsForCity(city.id);
        for (final district in districts) {
          districtToCity[district.id] = city.id;
          allDistricts.add(district);
        }
      }
    }
  }

  if (allDistricts.isEmpty) return const {};

  // Assign each visited cell to nearest district centroid.
  final districtCellCounts = <String, int>{};
  for (final district in allDistricts) {
    districtCellCounts[district.id] = 0;
  }

  for (final cellId in visitedCellIds) {
    final center = cellService.getCellCenter(cellId);
    String? nearestDistrictId;
    double nearestDist = double.infinity;

    for (final district in allDistricts) {
      final dLat = center.lat - district.centroidLat;
      final dLon = center.lon - district.centroidLon;
      final dist = dLat * dLat + dLon * dLon;
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestDistrictId = district.id;
      }
    }

    if (nearestDistrictId != null) {
      districtCellCounts[nearestDistrictId] =
          (districtCellCounts[nearestDistrictId] ?? 0) + 1;
    }
  }

  // Build district-level stats.
  final stats = <String, ExplorationStats>{};

  for (final district in allDistricts) {
    stats[district.id] = ExplorationStats(
      cellsExplored: districtCellCounts[district.id] ?? 0,
      cellsTotal: district.cellsTotal ?? 0,
    );
  }

  // Aggregate city-level stats (sum of districts).
  final cityStats = <String, ExplorationStats>{};
  for (final district in allDistricts) {
    final cityId = districtToCity[district.id]!;
    final ds = stats[district.id]!;
    cityStats[cityId] = (cityStats[cityId] ?? const ExplorationStats()) + ds;
  }
  stats.addAll(cityStats);

  // Aggregate state-level stats (sum of cities).
  final stateStats = <String, ExplorationStats>{};
  for (final entry in cityStats.entries) {
    final stateId = cityToState[entry.key];
    if (stateId != null) {
      stateStats[stateId] =
          (stateStats[stateId] ?? const ExplorationStats()) + entry.value;
    }
  }
  stats.addAll(stateStats);

  // Aggregate country-level stats (sum of states).
  final countryStats = <String, ExplorationStats>{};
  for (final entry in stateStats.entries) {
    final countryId = stateToCountry[entry.key];
    if (countryId != null) {
      countryStats[countryId] =
          (countryStats[countryId] ?? const ExplorationStats()) + entry.value;
    }
  }
  stats.addAll(countryStats);

  // Suppress unused variable warning.
  totalSpecies;

  return stats;
});
