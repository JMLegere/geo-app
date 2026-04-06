import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/iucn_status.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/domain/entities/taxonomic_group.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/core/domain/entities/game_region.dart';
import 'package:earth_nova/features/identification/domain/entities/pack_filter_state.dart';

void main() {
  group('PackFilterState', () {
    test('empty state has no active filters', () {
      const state = PackFilterState();
      expect(state.hasActiveFilters, isFalse);
      expect(state.activeFilterCount, 0);
    });

    test('toggleType adds and removes', () {
      const state = PackFilterState();
      final with1 = state.toggleType(TaxonomicGroup.mammals);
      expect(with1.activeTypes, {TaxonomicGroup.mammals});
      expect(with1.hasActiveFilters, isTrue);
      expect(with1.activeFilterCount, 1);

      final without = with1.toggleType(TaxonomicGroup.mammals);
      expect(without.activeTypes, isEmpty);
      expect(without.hasActiveFilters, isFalse);
    });

    test('toggleHabitat adds and removes', () {
      const state = PackFilterState();
      final with1 = state.toggleHabitat(Habitat.forest);
      expect(with1.activeHabitats, {Habitat.forest});

      final without = with1.toggleHabitat(Habitat.forest);
      expect(without.activeHabitats, isEmpty);
    });

    test('toggleRegion adds and removes', () {
      const state = PackFilterState();
      final with1 = state.toggleRegion(GameRegion.africa);
      expect(with1.activeRegions, {GameRegion.africa});

      final without = with1.toggleRegion(GameRegion.africa);
      expect(without.activeRegions, isEmpty);
    });

    test('toggleRarity adds and removes', () {
      const state = PackFilterState();
      final with1 = state.toggleRarity(IucnStatus.endangered);
      expect(with1.activeRarities, {IucnStatus.endangered});

      final without = with1.toggleRarity(IucnStatus.endangered);
      expect(without.activeRarities, isEmpty);
    });

    test('clearAll resets all dimensions', () {
      var state = const PackFilterState();
      state = state.toggleType(TaxonomicGroup.birds);
      state = state.toggleHabitat(Habitat.desert);
      state = state.toggleRegion(GameRegion.asia);
      expect(state.activeFilterCount, 3);

      final cleared = state.clearAll();
      expect(cleared.hasActiveFilters, isFalse);
      expect(cleared.activeFilterCount, 0);
    });

    test('matches returns true when no filters active', () {
      const filters = PackFilterState();
      final item = _fauna(taxonomicClass: 'MAMMALIA', habitats: ['Forest']);
      expect(filters.matches(item), isTrue);
    });

    test('type filter matches correct group', () {
      final filters =
          const PackFilterState().toggleType(TaxonomicGroup.mammals);
      expect(filters.matches(_fauna(taxonomicClass: 'MAMMALIA')), isTrue);
      expect(filters.matches(_fauna(taxonomicClass: 'AVES')), isFalse);
    });

    test('habitat filter matches items with matching habitat', () {
      final filters = const PackFilterState().toggleHabitat(Habitat.forest);
      expect(
        filters.matches(_fauna(habitats: ['Forest', 'Mountain'])),
        isTrue,
      );
      expect(
        filters.matches(_fauna(habitats: ['Desert'])),
        isFalse,
      );
    });

    test('habitat filter passes items with no habitats', () {
      final filters = const PackFilterState().toggleHabitat(Habitat.forest);
      expect(filters.matches(_fauna(habitats: [])), isTrue);
    });

    test('region filter matches items with matching continent', () {
      final filters = const PackFilterState().toggleRegion(GameRegion.africa);
      expect(
        filters.matches(_fauna(continents: ['Africa', 'Asia'])),
        isTrue,
      );
      expect(
        filters.matches(_fauna(continents: ['Europe'])),
        isFalse,
      );
    });

    test('region filter passes items with no continents', () {
      final filters = const PackFilterState().toggleRegion(GameRegion.africa);
      expect(filters.matches(_fauna(continents: [])), isTrue);
    });

    test('rarity filter matches items with matching rarity', () {
      final filters =
          const PackFilterState().toggleRarity(IucnStatus.endangered);
      expect(filters.matches(_fauna(rarity: 'EN')), isTrue);
      expect(filters.matches(_fauna(rarity: 'LC')), isFalse);
    });

    test('rarity filter rejects items with null rarity', () {
      final filters =
          const PackFilterState().toggleRarity(IucnStatus.endangered);
      expect(filters.matches(_fauna(rarity: null)), isFalse);
    });

    test('type filter passes non-fauna items (null taxonomicClass)', () {
      final filters =
          const PackFilterState().toggleType(TaxonomicGroup.mammals);
      final mineral = Item(
        id: 'test',
        definitionId: 'def',
        displayName: 'Quartz',
        category: ItemCategory.mineral,
        acquiredAt: DateTime(2026),
        status: ItemStatus.active,
      );
      expect(filters.matches(mineral), isTrue);
    });

    test('cross-dimension AND: type + habitat both must match', () {
      var filters = const PackFilterState();
      filters = filters.toggleType(TaxonomicGroup.mammals);
      filters = filters.toggleHabitat(Habitat.forest);
      // Mammal in forest → pass
      expect(
        filters.matches(_fauna(
          taxonomicClass: 'MAMMALIA',
          habitats: ['Forest'],
        )),
        isTrue,
      );
      // Mammal in desert → fail habitat
      expect(
        filters.matches(_fauna(
          taxonomicClass: 'MAMMALIA',
          habitats: ['Desert'],
        )),
        isFalse,
      );
      // Bird in forest → fail type
      expect(
        filters.matches(_fauna(
          taxonomicClass: 'AVES',
          habitats: ['Forest'],
        )),
        isFalse,
      );
    });

    test('equality works', () {
      final a = const PackFilterState().toggleType(TaxonomicGroup.mammals);
      final b = const PackFilterState().toggleType(TaxonomicGroup.mammals);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('inequality when different filters', () {
      final a = const PackFilterState().toggleType(TaxonomicGroup.mammals);
      final b = const PackFilterState().toggleType(TaxonomicGroup.birds);
      expect(a, isNot(equals(b)));
    });
  });
}

Item _fauna({
  String? taxonomicClass,
  String? rarity,
  List<String> habitats = const [],
  List<String> continents = const [],
}) =>
    Item(
      id: 'test',
      definitionId: 'def',
      displayName: 'Test Animal',
      category: ItemCategory.fauna,
      rarity: rarity,
      acquiredAt: DateTime(2026),
      status: ItemStatus.active,
      taxonomicClass: taxonomicClass,
      habitats: habitats,
      continents: continents,
    );
