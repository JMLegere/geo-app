import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/core/cells/cell_cache.dart';
import 'package:fog_of_world/core/cells/cell_service.dart';
import 'package:fog_of_world/core/cells/lazy_voronoi_cell_service.dart';
import 'package:fog_of_world/shared/constants.dart';

/// Provides the global [CellService] instance.
///
/// Uses [LazyVoronoiCellService] wrapped in [CellCache] for memoized boundary
/// lookups. Infinite-world Voronoi with deterministic seeds on a global grid.
final cellServiceProvider = Provider<CellService>((ref) {
  return CellCache(LazyVoronoiCellService(
    gridStep: kVoronoiGridStep,
    jitterFactor: kVoronoiJitterFactor,
    globalSeed: kVoronoiGlobalSeed,
    neighborRadius: kVoronoiNeighborRadius,
  ));
});
