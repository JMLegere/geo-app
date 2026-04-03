import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/domain/cells/cell_cache.dart';
import 'package:earth_nova/domain/cells/cell_service.dart';
import 'package:earth_nova/domain/cells/voronoi.dart';

/// The active [CellService] — a [CellCache] wrapping [LazyVoronoiCellService].
///
/// Singleton for the provider lifetime. The cache is cheap to create and
/// has built-in LRU eviction at 500 entries, so it is safe to share across
/// the whole app.
final cellServiceProvider = Provider<CellService>(
  (ref) => CellCache(LazyVoronoiCellService()),
);
