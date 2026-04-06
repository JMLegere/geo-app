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

    test('equality works', () {
      final a = const PackFilterState().toggleType(TaxonomicGroup.mammals);
      final b = const PackFilterState().toggleType(TaxonomicGroup.mammals);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
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
