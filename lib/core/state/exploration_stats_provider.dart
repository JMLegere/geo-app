import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/state/fog_resolver_provider.dart';

/// Per-region exploration statistics.
///
/// Computes the number of explored cells for each district, city, state, and
/// country by cross-referencing visited cell IDs with cell_properties.district_id.
///
/// For now, returns an empty map until cell→district assignment (Phase 4) is
/// wired. The hierarchy screens use this provider — when data is available,
/// they'll automatically update.
///
/// Future: watch cellPropertyRepository + fogResolver to compute real stats.
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
}

/// Provides exploration stats keyed by region ID (district, city, state, or country).
///
/// Currently returns empty map — will be populated when cell→district
/// assignment is wired (Phase 4 complete).
final explorationStatsProvider = Provider<Map<String, ExplorationStats>>((ref) {
  // Phase 5 stub: watch fog resolver for reactivity, return empty for now.
  ref.watch(fogResolverProvider);
  return const {};
});
