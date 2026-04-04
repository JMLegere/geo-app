import 'package:earth_nova/models/item.dart';
import 'package:earth_nova/shared/iconography.dart';

/// Immutable filter state for the Pack screen.
///
/// Encapsulates all filter selections across three dimensions:
///   - [activeTypes] — taxonomic groups (mammals, birds, etc.)
///   - [activeHabitats] — biomes (forest, desert, etc.)
///   - [activeRegions] — continents (Africa, Asia, etc.)
///
/// Filter logic:
///   - **OR within dimension** — selecting mammals + birds shows both
///   - **AND across dimensions** — mammals + forest = mammals in forests
///   - **Non-fauna items always pass** — minerals, fossils, etc. have no
///     taxonomic/habitat/region data, so they pass all filter dimensions
///
/// The [matches] predicate is the single source of truth for filtering.
/// Screens never implement their own filter logic.
class PackFilterState {
  const PackFilterState({
    this.activeTypes = const {},
    this.activeHabitats = const {},
    this.activeRegions = const {},
  });

  final Set<TaxonomicGroup> activeTypes;
  final Set<Habitat> activeHabitats;
  final Set<GameRegion> activeRegions;

  /// True if any filter dimension has active selections.
  bool get hasActiveFilters =>
      activeTypes.isNotEmpty ||
      activeHabitats.isNotEmpty ||
      activeRegions.isNotEmpty;

  /// Total number of active filter selections across all dimensions.
  int get activeFilterCount =>
      activeTypes.length + activeHabitats.length + activeRegions.length;

  // ── Toggle methods (return new instances — immutable) ───────────────────

  PackFilterState toggleType(TaxonomicGroup group) {
    final next = Set<TaxonomicGroup>.from(activeTypes);
    if (!next.remove(group)) next.add(group);
    return PackFilterState(
      activeTypes: next,
      activeHabitats: activeHabitats,
      activeRegions: activeRegions,
    );
  }

  PackFilterState toggleHabitat(Habitat habitat) {
    final next = Set<Habitat>.from(activeHabitats);
    if (!next.remove(habitat)) next.add(habitat);
    return PackFilterState(
      activeTypes: activeTypes,
      activeHabitats: next,
      activeRegions: activeRegions,
    );
  }

  PackFilterState toggleRegion(GameRegion region) {
    final next = Set<GameRegion>.from(activeRegions);
    if (!next.remove(region)) next.add(region);
    return PackFilterState(
      activeTypes: activeTypes,
      activeHabitats: activeHabitats,
      activeRegions: next,
    );
  }

  PackFilterState clearAll() => const PackFilterState();

  // ── The core filter predicate ──────────────────────────────────────────

  /// Returns true if [item] should be visible given current filter state.
  ///
  /// Non-biological items (null taxonomicClass, empty habitats/continents)
  /// always pass — they have no data to filter against.
  bool matches(Item item) {
    // Type filter: skip if no active types OR if item has no taxonomic data
    if (activeTypes.isNotEmpty && item.taxonomicClass != null) {
      if (!activeTypes.contains(item.taxonomicGroup)) return false;
    }

    // Habitat filter: skip if no active habitats OR if item has no habitats
    if (activeHabitats.isNotEmpty && item.habitats.isNotEmpty) {
      final itemHabitatSet =
          item.habitats.map(Habitat.fromString).whereType<Habitat>().toSet();
      if (itemHabitatSet.intersection(activeHabitats).isEmpty) return false;
    }

    // Region filter: skip if no active regions OR if item has no continents
    if (activeRegions.isNotEmpty && item.continents.isNotEmpty) {
      final itemRegionSet = item.continents
          .map(GameRegion.fromString)
          .whereType<GameRegion>()
          .toSet();
      if (itemRegionSet.intersection(activeRegions).isEmpty) return false;
    }

    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PackFilterState &&
          runtimeType == other.runtimeType &&
          _setEquals(activeTypes, other.activeTypes) &&
          _setEquals(activeHabitats, other.activeHabitats) &&
          _setEquals(activeRegions, other.activeRegions);

  @override
  int get hashCode => Object.hashAll([
        ...activeTypes,
        ...activeHabitats,
        ...activeRegions,
      ]);
}

bool _setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);
