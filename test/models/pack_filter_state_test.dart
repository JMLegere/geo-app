import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/models/item.dart';
import 'package:earth_nova/models/pack_filter_state.dart';
import 'package:earth_nova/shared/iconography.dart';

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

    test('activeFilterCount sums all dimensions', () {
      var state = const PackFilterState();
      state = state.toggleType(TaxonomicGroup.mammals);
      state = state.toggleType(TaxonomicGroup.birds);
      state = state.toggleHabitat(Habitat.forest);
      expect(state.activeFilterCount, 3);
    });

    group('matches', () {
      test('no filters → all items pass', () {
        const filters = PackFilterState();
        final item = _fauna(taxonomicClass: 'MAMMALIA', habitats: ['Forest']);
        expect(filters.matches(item), isTrue);
      });

      test('type filter matches correct group', () {
        final filters =
            const PackFilterState().toggleType(TaxonomicGroup.mammals);
        expect(
          filters.matches(_fauna(taxonomicClass: 'MAMMALIA')),
          isTrue,
        );
        expect(
          filters.matches(_fauna(taxonomicClass: 'AVES')),
          isFalse,
        );
      });

      test('type filter OR — mammals + birds both pass', () {
        var filters = const PackFilterState();
        filters = filters.toggleType(TaxonomicGroup.mammals);
        filters = filters.toggleType(TaxonomicGroup.birds);
        expect(
          filters.matches(_fauna(taxonomicClass: 'MAMMALIA')),
          isTrue,
        );
        expect(
          filters.matches(_fauna(taxonomicClass: 'AVES')),
          isTrue,
        );
        expect(
          filters.matches(_fauna(taxonomicClass: 'REPTILIA')),
          isFalse,
        );
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

      test('type + habitat = AND across dimensions', () {
        var filters = const PackFilterState();
        filters = filters.toggleType(TaxonomicGroup.mammals);
        filters = filters.toggleHabitat(Habitat.forest);

        // Mammal in forest → pass
        expect(
          filters.matches(
            _fauna(taxonomicClass: 'MAMMALIA', habitats: ['Forest']),
          ),
          isTrue,
        );
        // Mammal in desert → fail (habitat mismatch)
        expect(
          filters.matches(
            _fauna(taxonomicClass: 'MAMMALIA', habitats: ['Desert']),
          ),
          isFalse,
        );
        // Bird in forest → fail (type mismatch)
        expect(
          filters.matches(
            _fauna(taxonomicClass: 'AVES', habitats: ['Forest']),
          ),
          isFalse,
        );
      });

      test('non-fauna items always pass all filters', () {
        var filters = const PackFilterState();
        filters = filters.toggleType(TaxonomicGroup.mammals);
        filters = filters.toggleHabitat(Habitat.forest);
        filters = filters.toggleRegion(GameRegion.africa);

        final mineral = Item(
          id: 'mineral-1',
          definitionId: 'quartz',
          displayName: 'Quartz',
          category: ItemCategory.mineral,
          acquiredAt: DateTime(2026),
          status: ItemStatus.active,
        );
        // No taxonomicClass, no habitats, no continents → passes all
        expect(filters.matches(mineral), isTrue);
      });

      test('item with null taxonomicClass passes type filter', () {
        final filters =
            const PackFilterState().toggleType(TaxonomicGroup.mammals);
        final item = Item(
          id: '1',
          definitionId: 'def',
          displayName: 'Unknown',
          category: ItemCategory.fauna,
          acquiredAt: DateTime(2026),
          status: ItemStatus.active,
          // taxonomicClass is null
        );
        expect(filters.matches(item), isTrue);
      });

      test('item with empty habitats passes habitat filter', () {
        final filters = const PackFilterState().toggleHabitat(Habitat.forest);
        final item = _fauna(habitats: []);
        expect(filters.matches(item), isTrue);
      });
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
  List<String> habitats = const [],
  List<String> continents = const [],
}) =>
    Item(
      id: 'test',
      definitionId: 'def',
      displayName: 'Test Animal',
      category: ItemCategory.fauna,
      acquiredAt: DateTime(2026),
      status: ItemStatus.active,
      taxonomicClass: taxonomicClass,
      habitats: habitats,
      continents: continents,
    );
