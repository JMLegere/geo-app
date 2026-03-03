import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/species.dart';
import 'package:fog_of_world/core/species/loot_table.dart';

/// Full species service with deterministic per-cell encounter logic.
///
/// Uses a Path of Exile-style weighted loot table seeded by cell ID to
/// deterministically select which species a player can encounter in a given
/// cell. Species are filtered by habitat and continent before rolling.
class SpeciesService {
  final List<SpeciesRecord> _allRecords;

  /// Pre-built indices for fast lookup.
  late final Map<Habitat, List<SpeciesRecord>> _byHabitat;
  late final Map<Continent, List<SpeciesRecord>> _byContinent;
  late final Map<(Habitat, Continent), List<SpeciesRecord>>
      _byHabitatAndContinent;

  SpeciesService(this._allRecords) {
    _buildIndices();
  }

  /// All loaded species records.
  List<SpeciesRecord> get all => _allRecords;

  /// Total number of species in the dataset.
  int get totalSpecies => _allRecords.length;

  /// Get species available in a specific cell.
  ///
  /// This is the core encounter mechanic:
  /// 1. Filter species pool by [habitat] + [continent]
  /// 2. Build a weighted loot table (weights from IucnStatus)
  /// 3. Roll [encounterSlots] times deterministically (seeded by cellId)
  /// 4. Return the selected species (unique, no duplicates)
  ///
  /// [cellId] determines which species appear — same cell always gives same
  /// species. [encounterSlots] is how many rolls to attempt (default 3).
  List<SpeciesRecord> getSpeciesForCell({
    required String cellId,
    required Habitat habitat,
    required Continent continent,
    int encounterSlots = 3,
  }) {
    final pool = _byHabitatAndContinent[(habitat, continent)] ?? [];
    if (pool.isEmpty) return [];

    final table = LootTable<SpeciesRecord>(
      pool.map((s) => (s, s.iucnStatus.weight)).toList(),
    );

    return table.rollMultiple(cellId, encounterSlots);
  }

  /// Get ALL species that COULD appear in a habitat+continent combo.
  ///
  /// Useful for UI (showing "species possible in this area").
  List<SpeciesRecord> getPoolForArea({
    required Habitat habitat,
    required Continent continent,
  }) {
    return _byHabitatAndContinent[(habitat, continent)] ?? [];
  }

  /// Filter by habitat only.
  List<SpeciesRecord> forHabitat(Habitat habitat) =>
      _byHabitat[habitat] ?? [];

  /// Filter by continent only.
  List<SpeciesRecord> forContinent(Continent continent) =>
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
