import 'package:earth_nova/models/iucn_status.dart';
import 'package:earth_nova/models/item.dart';
import 'package:earth_nova/shared/iconography.dart';

/// Immutable filter state for the Pack screen.
///
/// Encapsulates all filter selections across four dimensions:
///   - [activeTypes] — taxonomic groups (mammals, birds, etc.)
///   - [activeHabitats] — biomes (forest, desert, etc.)
///   - [activeRegions] — continents (Africa, Asia, etc.)
///   - [activeRarities] — IUCN statuses (CR, EN, VU, NT, LC)
///
/// Filter logic:
///   - **OR within dimension** — selecting mammals + birds shows both
///   - **AND across dimensions** — mammals + forest = mammals in forests
///   - **Non-fauna items always pass** type/habitat/region filters —
///     minerals, fossils, etc. have no taxonomic data
///   - **Rarity filter applies to all categories** — every item has rarity
///
/// The [matches] predicate is the single source of truth for filtering.
/// Screens never implement their own filter logic.
class PackFilterState {
  const PackFilterState({
    this.activeTypes = const {},
    this.activeHabitats = const {},
    this.activeRegions = const {},
    this.activeRarities = const {},
  });

  final Set<TaxonomicGroup> activeTypes;
  final Set<Habitat> activeHabitats;
  final Set<GameRegion> activeRegions;
  final Set<IucnStatus> activeRarities;

  /// True if any filter dimension has active selections.
  bool get hasActiveFilters =>
      activeTypes.isNotEmpty ||
      activeHabitats.isNotEmpty ||
      activeRegions.isNotEmpty ||
      activeRarities.isNotEmpty;

  /// Total number of active filter selections across all dimensions.
  int get activeFilterCount =>
      activeTypes.length +
      activeHabitats.length +
      activeRegions.length +
      activeRarities.length;

  // ── Toggle methods (return new instances — immutable) ───────────────────

  PackFilterState toggleType(TaxonomicGroup group) {
    final next = Set<TaxonomicGroup>.from(activeTypes);
    if (!next.remove(group)) next.add(group);
    return _copyWith(activeTypes: next);
  }

  PackFilterState toggleHabitat(Habitat habitat) {
    final next = Set<Habitat>.from(activeHabitats);
    if (!next.remove(habitat)) next.add(habitat);
    return _copyWith(activeHabitats: next);
  }

  PackFilterState toggleRegion(GameRegion region) {
    final next = Set<GameRegion>.from(activeRegions);
    if (!next.remove(region)) next.add(region);
    return _copyWith(activeRegions: next);
  }

  PackFilterState toggleRarity(IucnStatus rarity) {
    final next = Set<IucnStatus>.from(activeRarities);
    if (!next.remove(rarity)) next.add(rarity);
    return _copyWith(activeRarities: next);
  }

  PackFilterState clearAll() => const PackFilterState();

  PackFilterState _copyWith({
    Set<TaxonomicGroup>? activeTypes,
    Set<Habitat>? activeHabitats,
    Set<GameRegion>? activeRegions,
    Set<IucnStatus>? activeRarities,
  }) =>
      PackFilterState(
        activeTypes: activeTypes ?? this.activeTypes,
        activeHabitats: activeHabitats ?? this.activeHabitats,
        activeRegions: activeRegions ?? this.activeRegions,
        activeRarities: activeRarities ?? this.activeRarities,
      );

  // ── The core filter predicate ──────────────────────────────────────────

  /// Returns true if [item] should be visible given current filter state.
  ///
  /// Non-biological items (null taxonomicClass, empty habitats/continents)
  /// always pass type/habitat/region — they have no data to filter against.
  /// Rarity filter applies to ALL categories.
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

    // Rarity filter: applies to all categories
    if (activeRarities.isNotEmpty) {
      final itemRarity = IucnStatus.fromString(item.rarity);
      if (itemRarity == null || !activeRarities.contains(itemRarity)) {
        return false;
      }
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
          _setEquals(activeRegions, other.activeRegions) &&
          _setEquals(activeRarities, other.activeRarities);

  @override
  int get hashCode => Object.hashAll([
        ...activeTypes,
        ...activeHabitats,
        ...activeRegions,
        ...activeRarities,
      ]);
}

bool _setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);
