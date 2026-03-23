import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:earth_nova/core/models/animal_type.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/species/loot_table.dart';
import 'package:earth_nova/core/species/species_cache.dart';
import 'package:earth_nova/shared/constants.dart';

/// Full species service with deterministic per-cell encounter logic.
///
/// Uses a three-stage rarity roll seeded by daily seed + cell ID to
/// deterministically select which species a player can encounter in a given
/// cell on a given day. Species are filtered by habitat(s) and continent before
/// rolling. Same cell + same day = same species. Different day = different species.
///
/// **Three-stage roll**:
/// - Stage 1: Pick a rarity tier using IucnStatus weights (243/81/27/9/3/1).
///   Eliminates dataset-composition bias — LC's 76% share no longer dominates.
/// - Stage 2: Pick an animal type with even weight from the types present in
///   that tier's pool. Ensures type diversity across rolls.
/// - Stage 3: Pick uniformly within the rarity × type pool.
///
/// Species without a recognized taxonomic class (null animalType) are pooled
/// together and treated as a synthetic extra type for Stage 2 fairness.
class SpeciesService {
  final List<FaunaDefinition> _allRecords;

  /// Cache-backed mode: set when constructed via [SpeciesService.fromCache].
  final SpeciesCache? _cache;

  /// Pre-built indices for fast lookup (list mode only).
  late final Map<Habitat, List<FaunaDefinition>> _byHabitat;
  late final Map<Continent, List<FaunaDefinition>> _byContinent;
  late final Map<(Habitat, Continent), List<FaunaDefinition>>
      _byHabitatAndContinent;

  /// Default constructor — builds in-memory indices from a full species list.
  ///
  /// Used directly in tests (inline fixtures) and as a production fallback
  /// for the "not loaded yet" state. Production code prefers
  /// [SpeciesService.fromCache].
  SpeciesService(this._allRecords) : _cache = null {
    _buildIndices();
  }

  /// Cache-backed constructor — uses [SpeciesCache] for sync DB-backed access.
  ///
  /// Does NOT build in-memory indices; [SpeciesCache.getCandidatesSync] handles
  /// all filtering.
  SpeciesService.fromCache({
    required SpeciesCache cache,
  })  : _cache = cache,
        _allRecords = const [] {
    // No index build — cache handles filtering.
    _byHabitat = const {};
    _byContinent = const {};
    _byHabitatAndContinent = const {};
  }

  /// All loaded species records.
  ///
  /// Only valid in list mode. In cache mode this is always empty — use
  /// [SpeciesCache] directly to query the full dataset.
  List<FaunaDefinition> get all => _allRecords;

  /// Total number of species in the dataset.
  int get totalSpecies => _cache?.totalSpeciesCount ?? _allRecords.length;

  // ── Cache-mode helpers ────────────────────────────────────────────────────

  /// Returns species candidates for (habitats, continent) from the cache.
  ///
  /// Only called when [_cache] is non-null (cache mode). The result is the
  /// union of all species matching any of the provided [habitats] × [continent].
  List<FaunaDefinition> _getPool(Set<Habitat> habitats, Continent continent) {
    return _cache!.getCandidatesSync(habitats: habitats, continent: continent);
  }

  /// Get species available in a specific cell.
  ///
  /// This is the core encounter mechanic:
  /// 1. Union species pools for all [habitats] × [continent] combinations
  /// 2. Group pool by rarity tier
  /// 3. Roll [encounterSlots] slots with three-stage rarity selection:
  ///    a. Pick a rarity tier using IucnStatus weights (3^x progression)
  ///    b. Pick an animal type with even weight from types in that tier
  ///    c. Pick uniformly within that rarity × type pool
  /// 4. Return the selected species (unique, no duplicates)
  ///
  /// [cellId] determines spatial location. [dailySeed] rotates species daily.
  /// Combined seed: `"${dailySeed}_${cellId}"` → same cell + same day =
  /// same species. Different day = different species.
  ///
  /// [encounterSlots] is how many rolls to attempt (default 3).
  ///
  /// Accepts a [Set<Habitat>] so that multi-biome cells (e.g. a coastal
  /// forest) draw from the union of all relevant species pools.
  List<FaunaDefinition> getSpeciesForCell({
    required String cellId,
    required String dailySeed,
    required Set<Habitat> habitats,
    required Continent continent,
    int encounterSlots = kEncounterSlotsPerCell,
  }) {
    var pool = <FaunaDefinition>{};
    if (_cache != null) {
      pool.addAll(_getPool(habitats, continent));
    } else {
      for (final habitat in habitats) {
        pool.addAll(_byHabitatAndContinent[(habitat, continent)] ?? []);
      }
    }
    // Fallback: plains is the default habitat when biome data hasn't loaded.
    // No IUCN species are tagged with "plains". Retry with forest (the most
    // common real habitat) so the player still gets discoveries.
    if (pool.isEmpty && habitats.contains(Habitat.plains)) {
      final fallback = (Set<Habitat>.from(habitats)..remove(Habitat.plains))
        ..add(Habitat.forest);
      if (_cache != null) {
        pool.addAll(_getPool(fallback, continent));
      } else {
        for (final habitat in fallback) {
          pool.addAll(_byHabitatAndContinent[(habitat, continent)] ?? []);
        }
      }
    }
    if (pool.isEmpty) return [];

    // Daily seed + cell ID → species rotate daily per cell.
    final combinedSeed = '${dailySeed}_$cellId';
    return _rollThreeStageMultiple(
        combinedSeed, encounterSlots, _groupByRarity(pool));
  }

  /// Get ALL species that COULD appear in a set of habitats + continent.
  ///
  /// Returns the union of species pools across all provided [habitats].
  /// Useful for UI (showing "species possible in this area").
  List<FaunaDefinition> getPoolForArea({
    required Set<Habitat> habitats,
    required Continent continent,
  }) {
    if (_cache != null) {
      return _getPool(habitats, continent);
    }
    final pool = <FaunaDefinition>{};
    for (final habitat in habitats) {
      pool.addAll(_byHabitatAndContinent[(habitat, continent)] ?? []);
    }
    return pool.toList();
  }

  /// Get species for a **Migration** event.
  ///
  /// Migration brings species from a different continent, preferring those
  /// with a different climate than the cell's native climate. This simulates
  /// migratory species passing through the player's area.
  ///
  /// 1. Deterministically pick a source continent ≠ [nativeContinent]
  ///    (seeded by `"${dailySeed}_migration_continent_${cellId}"`).
  /// 2. Build pool from [habitats] × sourceContinent.
  /// 3. Prefer species with `climate ≠ nativeClimate` when enrichment data
  ///    is available. Falls back to full pool if too few have climate data.
  /// 4. Roll [encounterSlots] species from the filtered pool.
  List<FaunaDefinition> getSpeciesForMigration({
    required String cellId,
    required String dailySeed,
    required Set<Habitat> habitats,
    required Continent nativeContinent,
    required Climate nativeClimate,
    int encounterSlots = kEncounterSlotsPerCell,
  }) {
    // 1. Deterministically pick a source continent ≠ nativeContinent.
    final otherContinents =
        Continent.values.where((c) => c != nativeContinent).toList();
    if (otherContinents.isEmpty) return [];

    final continentHash = sha256
        .convert(utf8.encode('${dailySeed}_migration_continent_$cellId'))
        .bytes;
    final continentIdx = (((continentHash[0] << 24) |
                (continentHash[1] << 16) |
                (continentHash[2] << 8) |
                continentHash[3]) &
            0x7FFFFFFF) %
        otherContinents.length;
    final sourceContinent = otherContinents[continentIdx];

    // 2. Build pool from habitats × sourceContinent.
    final pool = <FaunaDefinition>{};
    if (_cache != null) {
      pool.addAll(_getPool(habitats, sourceContinent));
    } else {
      for (final habitat in habitats) {
        pool.addAll(_byHabitatAndContinent[(habitat, sourceContinent)] ?? []);
      }
    }
    if (pool.isEmpty) return [];

    // 3. Prefer species with different climate (when enrichment is available).
    final differentClimatePool = pool
        .where((s) => s.climate != null && s.climate != nativeClimate)
        .toList();
    final effectivePool =
        differentClimatePool.isNotEmpty ? differentClimatePool : pool.toList();

    // 4. Roll from the effective pool using three-stage rarity selection.
    return _rollThreeStageMultiple(
      '${dailySeed}_$cellId',
      encounterSlots,
      _groupByRarity(effectivePool),
    );
  }

  /// Get species for a **Nesting Site** event.
  ///
  /// Nesting sites guarantee encounters with rare species (Endangered,
  /// Critically Endangered, or Extinct) from the cell's native habitats
  /// and continent. Standard rarity weights still apply within the rare pool
  /// (EN is more common than CR, CR more than EX).
  ///
  /// Returns empty if no EN/CR/EX species exist in the habitat × continent
  /// pool. The caller should fall back to normal encounters in that case.
  List<FaunaDefinition> getSpeciesForNestingSite({
    required String cellId,
    required String dailySeed,
    required Set<Habitat> habitats,
    required Continent continent,
    int encounterSlots = kEncounterSlotsPerCell,
  }) {
    // 1. Build the normal species pool (same as getSpeciesForCell).
    final pool = <FaunaDefinition>{};
    if (_cache != null) {
      pool.addAll(_getPool(habitats, continent));
    } else {
      for (final habitat in habitats) {
        pool.addAll(_byHabitatAndContinent[(habitat, continent)] ?? []);
      }
    }

    // 2. Filter to EN/CR/EX only.
    final rarePool = pool.where((s) {
      final rarity = s.rarity;
      return rarity == IucnStatus.endangered ||
          rarity == IucnStatus.criticallyEndangered ||
          rarity == IucnStatus.extinct;
    }).toList();
    if (rarePool.isEmpty) return [];

    // 3. Roll with three-stage selection within the rare pool
    //    (tier weights EN=9 > CR=3 > EX=1 preserved via tier table).
    return _rollThreeStageMultiple(
      '${dailySeed}_$cellId',
      encounterSlots,
      _groupByRarity(rarePool),
    );
  }

  /// Filter by habitat only.
  List<FaunaDefinition> forHabitat(Habitat habitat) =>
      _byHabitat[habitat] ?? [];

  /// Filter by continent only.
  List<FaunaDefinition> forContinent(Continent continent) =>
      _byContinent[continent] ?? [];

  /// Groups a species collection by IUCN rarity tier.
  ///
  /// Only includes tiers that have at least one species in [pool].
  /// Species without a rarity are silently excluded (should not happen in
  /// practice — the species repository skips records with unknown IUCN status).
  Map<IucnStatus, List<FaunaDefinition>> _groupByRarity(
      Iterable<FaunaDefinition> pool) {
    final result = <IucnStatus, List<FaunaDefinition>>{};
    for (final s in pool) {
      if (s.rarity != null) {
        (result[s.rarity!] ??= []).add(s);
      }
    }
    return result;
  }

  /// Three-stage rarity roll: tier → animal type → uniform pick within type.
  ///
  /// **Stage 1**: Build a [LootTable] over the rarity tiers present in
  /// [poolByRarity], weighted by [IucnStatus.weight] (3^x). Roll to select
  /// a tier. This step is dataset-composition-independent — a pool with 900
  /// LC and 100 EN species still gives EN a 9/252 ≈ 3.6% tier-hit chance.
  ///
  /// **Stage 2**: Within the selected tier's pool, group by [AnimalType]
  /// (mammal/bird/fish/reptile/bug) and pick a type with **even weight**.
  /// Species with null animalType are grouped into a synthetic "unknown"
  /// bucket. Types are sorted by enum index for stable ordering. This ensures
  /// type diversity across rolls — no single type dominates by pool size alone.
  ///
  /// **Stage 3**: Pick uniformly within the rarity × type pool, seeded by a
  /// domain-separated hash.
  ///
  /// Uniqueness: if the rolled species was already selected this call, we
  /// retry (up to [n] × 10 total attempts).
  ///
  /// Seed format: `"${baseSeed}_${attempt}_t"` for tier, `"${baseSeed}_${attempt}_ty"` for type, `"${baseSeed}_${attempt}_s"` for species.
  List<FaunaDefinition> _rollThreeStageMultiple(
    String baseSeed,
    int n,
    Map<IucnStatus, List<FaunaDefinition>> poolByRarity,
  ) {
    if (poolByRarity.isEmpty) return [];

    // Build tier selection table from the tiers present in this pool.
    final tierEntries =
        poolByRarity.entries.map((e) => (e.key, e.key.weight)).toList();
    final tierTable = LootTable<IucnStatus>(tierEntries);

    final results = <FaunaDefinition>[];
    final seen = <FaunaDefinition>{};
    var attempt = 0;
    final maxAttempts = n * 10;

    while (results.length < n && attempt < maxAttempts) {
      final attemptSeed = '${baseSeed}_$attempt';

      // Stage 1: pick rarity tier (weighted by IucnStatus.weight).
      final tier = tierTable.roll('${attemptSeed}_t');
      final tierPool = poolByRarity[tier]!;

      // Stage 2: pick animal type with even weight.
      // Group tier pool by AnimalType. Null animalType → sentinel null key.
      final typeMap = <AnimalType?, List<FaunaDefinition>>{};
      for (final s in tierPool) {
        (typeMap[s.animalType] ??= []).add(s);
      }
      // Sort keys for stable ordering: known types by enum index, null last.
      final typeKeys = typeMap.keys.toList()
        ..sort((a, b) {
          if (a == null) return 1;
          if (b == null) return -1;
          return a.index.compareTo(b.index);
        });
      final typeHash = sha256.convert(utf8.encode('${attemptSeed}_ty')).bytes;
      final typeIdx = (((typeHash[0] << 24) |
                  (typeHash[1] << 16) |
                  (typeHash[2] << 8) |
                  typeHash[3]) &
              0x7FFFFFFF) %
          typeKeys.length;
      final chosenType = typeKeys[typeIdx];
      final typePool = typeMap[chosenType]!;

      // Stage 3: pick uniformly within rarity × type pool.
      final hash = sha256.convert(utf8.encode('${attemptSeed}_s')).bytes;
      final idx =
          (((hash[0] << 24) | (hash[1] << 16) | (hash[2] << 8) | hash[3]) &
                  0x7FFFFFFF) %
              typePool.length;
      final species = typePool[idx];

      if (seen.add(species)) {
        results.add(species);
      }
      attempt++;
    }
    return results;
  }

  void _buildIndices() {
    _byHabitat = {};
    _byContinent = {};
    _byHabitatAndContinent = {};

    for (final record in _allRecords) {
      for (final habitat in record.habitats) {
        (_byHabitat[habitat] ??= []).add(record);
        for (final continent in record.continents) {
          (_byContinent[continent] ??= []).add(record);
          (_byHabitatAndContinent[(habitat, continent)] ??= []).add(record);
        }
      }
    }

    // Deduplicate continent index: species with multiple habitats get added
    // once per habitat in the inner loop, so de-dup after the fact.
    for (final key in _byContinent.keys) {
      _byContinent[key] = _byContinent[key]!.toSet().toList();
    }
  }
}
