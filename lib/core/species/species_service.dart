import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/item_definition.dart';
import 'package:fog_of_world/core/species/loot_table.dart';

/// Full species service with deterministic per-cell encounter logic.
///
/// Uses a Path of Exile-style weighted loot table seeded by daily seed + cell ID
/// to deterministically select which species a player can encounter in a given
/// cell on a given day. Species are filtered by habitat(s) and continent before
/// rolling. Same cell + same day = same species. Different day = different species.
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
  /// 2. Build a single weighted loot table (weights from IucnStatus)
  /// 3. Roll [encounterSlots] times deterministically (seeded by dailySeed + cellId)
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
    int encounterSlots = 3,
  }) {
    final pool = <FaunaDefinition>{};
    for (final habitat in habitats) {
      pool.addAll(_byHabitatAndContinent[(habitat, continent)] ?? []);
    }
    if (pool.isEmpty) return [];

    final table = LootTable<FaunaDefinition>(
      pool.map((s) => (s, s.rarity!.weight)).toList(),
    );

    // Daily seed + cell ID → species rotate daily per cell.
    final combinedSeed = '${dailySeed}_$cellId';
    return table.rollMultiple(combinedSeed, encounterSlots);
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

  /// Filter by habitat only.
  List<FaunaDefinition> forHabitat(Habitat habitat) =>
      _byHabitat[habitat] ?? [];

  /// Filter by continent only.
  List<FaunaDefinition> forContinent(Continent continent) =>
      _byContinent[continent] ?? [];

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
