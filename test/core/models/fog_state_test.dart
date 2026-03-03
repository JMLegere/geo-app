import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/fog_state.dart';

void main() {
  group('FogState', () {
    test('all 5 states exist', () {
      expect(FogState.undetected, isNotNull);
      expect(FogState.unexplored, isNotNull);
      expect(FogState.hidden, isNotNull);
      expect(FogState.concealed, isNotNull);
      expect(FogState.observed, isNotNull);
    });

    test('density mapping is correct', () {
      expect(FogState.undetected.density, equals(1.0));
      expect(FogState.unexplored.density, equals(0.75));
      expect(FogState.hidden.density, equals(0.5));
      expect(FogState.concealed.density, equals(0.25));
      expect(FogState.observed.density, equals(0.0));
    });

    test('isObserved is true only for observed state', () {
      expect(FogState.observed.isObserved, isTrue);
      expect(FogState.concealed.isObserved, isFalse);
      expect(FogState.hidden.isObserved, isFalse);
      expect(FogState.unexplored.isObserved, isFalse);
      expect(FogState.undetected.isObserved, isFalse);
    });

    test('isVisited is true only for hidden and observed', () {
      // States that imply the player has physically visited the cell.
      expect(FogState.hidden.isVisited, isTrue);
      expect(FogState.observed.isVisited, isTrue);
      // States that do NOT imply a visit.
      expect(FogState.undetected.isVisited, isFalse);
      expect(FogState.unexplored.isVisited, isFalse);
      expect(FogState.concealed.isVisited, isFalse);
    });

    test('density ordering is consistent with state index', () {
      // Higher index states have lower (more transparent) fog density.
      for (var i = 0; i < FogState.values.length - 1; i++) {
        expect(
          FogState.values[i].density,
          greaterThan(FogState.values[i + 1].density),
          reason:
              '${FogState.values[i].name} should have higher density than '
              '${FogState.values[i + 1].name}',
        );
      }
    });

    test('fromString parses all states correctly', () {
      expect(FogState.fromString('undetected'), equals(FogState.undetected));
      expect(FogState.fromString('unexplored'), equals(FogState.unexplored));
      expect(FogState.fromString('hidden'), equals(FogState.hidden));
      expect(FogState.fromString('concealed'), equals(FogState.concealed));
      expect(FogState.fromString('observed'), equals(FogState.observed));
    });

    test('toString returns state name', () {
      expect(FogState.undetected.toString(), equals('undetected'));
      expect(FogState.unexplored.toString(), equals('unexplored'));
      expect(FogState.hidden.toString(), equals('hidden'));
      expect(FogState.concealed.toString(), equals('concealed'));
      expect(FogState.observed.toString(), equals('observed'));
    });
  });
}
