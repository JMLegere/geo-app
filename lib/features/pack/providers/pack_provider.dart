import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/models/item_definition.dart';
import 'package:fog_of_world/core/state/inventory_provider.dart';
import 'package:fog_of_world/features/discovery/providers/discovery_provider.dart';

// ---------------------------------------------------------------------------
// Filter enums
// ---------------------------------------------------------------------------

/// Filter by habitat type; [all] means no habitat restriction.
enum HabitatFilter {
  all,
  forest,
  plains,
  freshwater,
  saltwater,
  swamp,
  mountain,
  desert;

  String get displayName => switch (this) {
        HabitatFilter.all => 'All',
        HabitatFilter.forest => 'Forest',
        HabitatFilter.plains => 'Plains',
        HabitatFilter.freshwater => 'Freshwater',
        HabitatFilter.saltwater => 'Saltwater',
        HabitatFilter.swamp => 'Swamp',
        HabitatFilter.mountain => 'Mountain',
        HabitatFilter.desert => 'Desert',
      };

  /// Corresponding [Habitat] value, or null when [all].
  Habitat? get habitat => switch (this) {
        HabitatFilter.all => null,
        HabitatFilter.forest => Habitat.forest,
        HabitatFilter.plains => Habitat.plains,
        HabitatFilter.freshwater => Habitat.freshwater,
        HabitatFilter.saltwater => Habitat.saltwater,
        HabitatFilter.swamp => Habitat.swamp,
        HabitatFilter.mountain => Habitat.mountain,
        HabitatFilter.desert => Habitat.desert,
      };
}

/// Filter by IUCN rarity tier; [all] means no rarity restriction.
enum RarityFilter {
  all,
  leastConcern,
  nearThreatened,
  vulnerable,
  endangered,
  criticallyEndangered,
  extinct;

  String get displayName => switch (this) {
        RarityFilter.all => 'All',
        RarityFilter.leastConcern => 'LC',
        RarityFilter.nearThreatened => 'NT',
        RarityFilter.vulnerable => 'VU',
        RarityFilter.endangered => 'EN',
        RarityFilter.criticallyEndangered => 'CR',
        RarityFilter.extinct => 'EX',
      };

  /// Corresponding [IucnStatus] value, or null when [all].
  IucnStatus? get status => switch (this) {
        RarityFilter.all => null,
        RarityFilter.leastConcern => IucnStatus.leastConcern,
        RarityFilter.nearThreatened => IucnStatus.nearThreatened,
        RarityFilter.vulnerable => IucnStatus.vulnerable,
        RarityFilter.endangered => IucnStatus.endangered,
        RarityFilter.criticallyEndangered => IucnStatus.criticallyEndangered,
        RarityFilter.extinct => IucnStatus.extinct,
      };
}

/// Filter by collection status.
enum CollectionFilter {
  all,
  collected,
  undiscovered;

  String get displayName => switch (this) {
        CollectionFilter.all => 'All',
        CollectionFilter.collected => 'Collected',
        CollectionFilter.undiscovered => 'Undiscovered',
      };
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable snapshot of the pack subsystem state.
class PackState {
  /// Full pool of species available to the player.
  final List<FaunaDefinition> allSpecies;

  /// IDs of species the player has collected (from [collectionProvider]).
  final Set<String> collectedIds;

  /// Active habitat filter (default: [HabitatFilter.all]).
  final HabitatFilter habitatFilter;

  /// Active rarity filter (default: [RarityFilter.all]).
  final RarityFilter rarityFilter;

  /// Active collection filter (default: [CollectionFilter.all]).
  final CollectionFilter collectionFilter;

  const PackState({
    this.allSpecies = const <FaunaDefinition>[],
    this.collectedIds = const {},
    this.habitatFilter = HabitatFilter.all,
    this.rarityFilter = RarityFilter.all,
    this.collectionFilter = CollectionFilter.all,
  });

  /// Applies all active filters (AND logic) and returns the matching subset.
  List<FaunaDefinition> get filteredSpecies {
    return allSpecies.where((s) {
      // Collection filter
      final isCollected = collectedIds.contains(s.id);
      if (collectionFilter == CollectionFilter.collected && !isCollected) {
        return false;
      }
      if (collectionFilter == CollectionFilter.undiscovered && isCollected) {
        return false;
      }

      // Habitat filter
      final targetHabitat = habitatFilter.habitat;
      if (targetHabitat != null && !s.habitats.contains(targetHabitat)) {
        return false;
      }

      // Rarity filter
      final targetStatus = rarityFilter.status;
      if (targetStatus != null && s.rarity != targetStatus) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Total number of species in the player's pool.
  int get totalCount => allSpecies.length;

  /// Number of species the player has collected.
  int get collectedCount => collectedIds.length;

  PackState copyWith({
    List<FaunaDefinition>? allSpecies,
    Set<String>? collectedIds,
    HabitatFilter? habitatFilter,
    RarityFilter? rarityFilter,
    CollectionFilter? collectionFilter,
  }) {
    return PackState(
      allSpecies: allSpecies ?? this.allSpecies,
      collectedIds: collectedIds ?? this.collectedIds,
      habitatFilter: habitatFilter ?? this.habitatFilter,
      rarityFilter: rarityFilter ?? this.rarityFilter,
      collectionFilter: collectionFilter ?? this.collectionFilter,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class PackNotifier extends Notifier<PackState> {
  @override
  PackState build() {
    // Watch species service — rebuilds if the species pool ever changes.
    final speciesService = ref.watch(speciesServiceProvider);

    // Listen to inventory changes and update collectedIds only,
    // preserving active filter selections.
    ref.listen(inventoryProvider, (_, next) {
      updateCollectedIds(next.uniqueDefinitionIds);
    });

    // Read inventory for initial state (listen handles ongoing changes).
    final collectedIds = ref.read(inventoryProvider).uniqueDefinitionIds;

    return PackState(
      allSpecies: speciesService.all,
      collectedIds: collectedIds,
    );
  }

  void setHabitatFilter(HabitatFilter filter) {
    state = state.copyWith(habitatFilter: filter);
  }

  void setRarityFilter(RarityFilter filter) {
    state = state.copyWith(rarityFilter: filter);
  }

  void setCollectionFilter(CollectionFilter filter) {
    state = state.copyWith(collectionFilter: filter);
  }

  /// Replaces the full species list (used when species pool changes).
  void updateSpecies(List<FaunaDefinition> species) {
    state = state.copyWith(allSpecies: species);
  }

  /// Syncs collected IDs from the collection provider.
  void updateCollectedIds(Set<String> ids) {
    state = state.copyWith(collectedIds: ids);
  }
}

/// Global provider for [PackNotifier].
final packProvider =
    NotifierProvider<PackNotifier, PackState>(PackNotifier.new);
