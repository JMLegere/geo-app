import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/species/species_repository.dart';

/// In-memory cache wrapping [SpeciesRepository] for sync access during the
/// ~10 Hz game tick.
///
/// [warmUp] is called async during player area hydration. After warming,
/// [getCandidatesSync] provides O(1) lookup without touching the database.
///
/// Cache keys are deterministic: sorted habitat names + continent name,
/// joined as `"forest,mountain:northAmerica"`. The same (habitat set,
/// continent) combination always maps to the same key regardless of insertion
/// order.
class SpeciesCache {
  final SpeciesRepository? _repo;

  /// Candidates cache: cache-key → species list.
  final Map<String, List<FaunaDefinition>> _cache = {};

  /// Id cache: definitionId → FaunaDefinition for sync lookup.
  final Map<String, FaunaDefinition> _byId = {};

  int? _totalCount;

  /// Creates a [SpeciesCache] backed by [repo].
  SpeciesCache(SpeciesRepository repo) : _repo = repo;

  /// Creates an empty cache with no backing repository.
  ///
  /// Used as a fallback while [speciesCacheProvider] is loading, so callers
  /// never get a null cache — just an empty one.
  SpeciesCache.empty() : _repo = null;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Async warm-up for the player's current area.
  ///
  /// Queries the DB and stores the result in [_cache]. Subsequent calls for
  /// the same (habitats, continent) are no-ops. Safe to call multiple times.
  Future<void> warmUp({
    required Set<Habitat> habitats,
    required Continent continent,
  }) async {
    if (_repo == null || habitats.isEmpty) return;
    final key = _cacheKey(habitats, continent);
    if (_cache.containsKey(key)) return;
    final candidates = await _repo!.getCandidates(
      habitats: habitats,
      continent: continent,
    );
    _cache[key] = candidates;
    for (final def in candidates) {
      _byId[def.id] = def;
    }
  }

  /// Sync lookup — returns cached candidates or an empty list if not warmed.
  ///
  /// This is the hot path called by SpeciesService during each game tick.
  /// Never touches the database; returns empty if [warmUp] hasn't been called
  /// for this (habitats, continent) combination yet.
  List<FaunaDefinition> getCandidatesSync({
    required Set<Habitat> habitats,
    required Continent continent,
  }) {
    if (habitats.isEmpty) return const [];
    return _cache[_cacheKey(habitats, continent)] ?? const [];
  }

  /// Sync lookup by definition ID — returns null if not cached.
  FaunaDefinition? getByIdSync(String id) => _byId[id];

  /// Total species count — returns 0 until [loadTotalCount] has been called.
  int get totalSpeciesCount => _totalCount ?? 0;

  /// Pre-fetches and caches the total species count from the DB.
  Future<void> loadTotalCount() async {
    if (_repo == null) return;
    _totalCount ??= await _repo!.count();
  }

  /// Returns true when this cache has no backing repository (created via
  /// [SpeciesCache.empty]) — i.e. the repository is still loading.
  bool get isEmpty => _repo == null;

  /// Clears all cached species data.
  ///
  /// Call on sign-out or when the app receives a low-memory warning.
  void clear() {
    _cache.clear();
    _byId.clear();
    _totalCount = null;
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  /// Builds a stable, order-independent cache key from a habitat set and
  /// continent. Example: `"forest,mountain:northAmerica"`.
  static String _cacheKey(Set<Habitat> habitats, Continent continent) {
    final sorted = habitats.map((h) => h.name).toList()..sort();
    return '${sorted.join(',')}:${continent.name}';
  }
}
