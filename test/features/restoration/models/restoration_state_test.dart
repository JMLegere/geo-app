import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/restoration/models/restoration_state.dart';

void main() {
  group('RestorationState', () {
    test('constructs with empty defaults', () {
      const state = RestorationState();
      expect(state.levels, isEmpty);
      expect(state.cellSpecies, isEmpty);
    });

    test('constructs with provided levels and cellSpecies', () {
      final levels = <String, double>{'cell1': 0.5};
      final cellSpecies = <String, Set<String>>{
        'cell1': {'sp1', 'sp2'},
      };
      final state = RestorationState(levels: levels, cellSpecies: cellSpecies);
      expect(state.levels, equals({'cell1': 0.5}));
      expect(state.cellSpecies['cell1'], containsAll(['sp1', 'sp2']));
    });

    test('copyWith replaces levels', () {
      const original = RestorationState();
      final updated = original.copyWith(levels: {'cell1': 0.33});
      expect(updated.levels, equals({'cell1': 0.33}));
      expect(updated.cellSpecies, isEmpty);
    });

    test('copyWith replaces cellSpecies', () {
      const original = RestorationState();
      final updated = original.copyWith(
        cellSpecies: {
          'cell1': {'sp1'},
        },
      );
      expect(updated.cellSpecies['cell1'], contains('sp1'));
      expect(updated.levels, isEmpty);
    });

    test('copyWith preserves unchanged fields', () {
      final state = RestorationState(
        levels: {'cell1': 0.66},
        cellSpecies: {
          'cell1': {'sp1', 'sp2'},
        },
      );
      final updated = state.copyWith(levels: {'cell1': 1.0});
      expect(updated.levels, equals({'cell1': 1.0}));
      expect(updated.cellSpecies['cell1'], containsAll(['sp1', 'sp2']));
    });

    test('copyWith with no arguments returns equivalent state', () {
      final state = RestorationState(
        levels: {'cell1': 0.33},
        cellSpecies: {
          'cell1': {'sp1'},
        },
      );
      final copy = state.copyWith();
      expect(copy.levels, equals({'cell1': 0.33}));
      expect(copy.cellSpecies['cell1'], contains('sp1'));
    });
  });
}
