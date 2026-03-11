import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/species/loot_table.dart';
import 'package:earth_nova/shared/constants.dart';

/// Full species service with deterministic per-cell encounter logic.
///
/// Uses a two-stage rarity roll seeded by daily seed + cell ID to
/// deterministically select which species a player can encounter in a given
/// cell on a given day. Species are filtered by habitat(s) and continent before
/// rolling. Same cell + same day = same species. Different day = different species.
///
/// **Two-stage roll**: Stage 1 picks a rarity tier using IucnStatus weights
/// (243/81/27/9/3/1). Stage 2 picks uniformly within that tier's species pool.
/// This eliminates dataset-composition bias: the 76% LC dataset no longer
/// inflates encounter rates — tier selection is independent of pool sizes.
class SpeciesService {
  final List<FaunaDefinition> _allRecords;

  /// Pre-built indices for fast lookup.
  late final Map<Habitat, List<FaunaDefinition>> _byHabitat;
  late final Map<Continent, List<FaunaDefinition>> _byContinent;
  late final Map<(Habitat, Continent), List<FaunaDefinition>>
      _byHabitatAndContinent;

  SpeciesService(this._allRecords) {
    _buildIndices();
  }

  /// All loaded species records.
  List<FaunaDefinition> get all => _allRecords;

  /// Total number of species in the dataset.
  int get totalSpecies => _allRecords.length;

  /// Get species available in a specific cell.
  ///
  /// This is the core encounter mechanic:
  /// 1. Union species pools for all [habitats] × [continent] combinations
  /// 2. Group pool by rarity tier
  /// 3. Roll [encounterSlots] slots with two-stage rarity selection:
  ///    a. Pick a rarity tier using IucnStatus weights (3^x progression)
  ///    b. Pick uniformly within that tier's species
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
    final pool = <FaunaDefinition>{};
    for (final habitat in habitats) {
      pool.addAll(_byHabitatAndContinent[(habitat, continent)] ?? []);
    }
    if (pool.isEmpty) return [];

    // Daily seed + cell ID → species rotate daily per cell.
    final combinedSeed = '${dailySeed}_$cellId';
    return _rollTwoStageMultiple(
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
    for (final habitat in habitats) {
      pool.addAll(_byHabitatAndContinent[(habitat, sourceContinent)] ?? []);
    }
    if (pool.isEmpty) return [];

    // 3. Prefer species with different climate (when enrichment is available).
    final differentClimatePool = pool
        .where((s) => s.climate != null && s.climate != nativeClimate)
        .toList();
    final effectivePool =
        differentClimatePool.isNotEmpty ? differentClimatePool : pool.toList();

    // 4. Roll from the effective pool using two-stage rarity selection.
    return _rollTwoStageMultiple(
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
    for (final habitat in habitats) {
      pool.addAll(_byHabitatAndContinent[(habitat, continent)] ?? []);
    }

    // 2. Filter to EN/CR/EX only.
    final rarePool = pool.where((s) {
      final rarity = s.rarity;
      return rarity == IucnStatus.endangered ||
          rarity == IucnStatus.criticallyEndangered ||
          rarity == IucnStatus.extinct;
    }).toList();
    if (rarePool.isEmpty) return [];

    // 3. Roll with two-stage selection within the rare pool
    //    (tier weights EN=9 > CR=3 > EX=1 preserved via tier table).
    return _rollTwoStageMultiple(
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
  /// practice — [SpeciesDataLoader] skips records with unknown IUCN status).
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

  /// Two-stage rarity roll: pick tier first, then pick uniformly within tier.
  ///
  /// **Stage 1**: Build a [LootTable] over the rarity tiers present in
  /// [poolByRarity], weighted by [IucnStatus.weight] (3^x). Roll to select
  /// a tier. This step is dataset-composition-independent — a pool with 900
  /// LC and 100 EN species still gives EN a 9/252 ≈ 3.6% tier-hit chance,
  /// not 0.2% as weighted-flat would.
  ///
  /// **Stage 2**: Pick uniformly within the selected tier's species list,
  /// seeded by a domain-separated hash.
  ///
  /// Uniqueness: if the rolled species was already selected this call, we
  /// retry (up to [n] × 10 total attempts). If a tier becomes exhausted
  /// (all species already selected), that tier still gets hit by Stage 1
  /// and the attempt is simply wasted — this is rare and bounded by
  /// [maxAttempts].
  ///
  /// Seed format: `"${baseSeed}_${attempt}_t"` for tier, `"${baseSeed}_${attempt}_s"` for species.
  List<FaunaDefinition> _rollTwoStageMultiple(
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

      // Stage 1: pick rarity tier.
      final tier = tierTable.roll('${attemptSeed}_t');

      // Stage 2: pick uniformly within tier's pool.
      final tierPool = poolByRarity[tier]!;
      final hash = sha256.convert(utf8.encode('${attemptSeed}_s')).bytes;
      final idx =
          (((hash[0] << 24) | (hash[1] << 16) | (hash[2] << 8) | hash[3]) &
                  0x7FFFFFFF) %
              tierPool.length;
      final species = tierPool[idx];

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
