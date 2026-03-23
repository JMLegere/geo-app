import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/fog_state.dart';

void main() {
  group('FogState', () {
    test('all 5 states exist', () {
      expect(FogState.unknown, isNotNull);
      expect(FogState.detected, isNotNull);
      expect(FogState.visited, isNotNull);
      expect(FogState.nearby, isNotNull);
      expect(FogState.active, isNotNull);
    });

    test('density mapping is correct', () {
      expect(FogState.unknown.density, equals(1.0));
      expect(FogState.detected.density, equals(1.0));
      expect(FogState.nearby.density, equals(0.95));
      expect(FogState.visited.density, equals(0.5));
      expect(FogState.active.density, equals(0.0));
    });

    test('isObserved is true only for observed state', () {
      expect(FogState.active.isObserved, isTrue);
      expect(FogState.nearby.isObserved, isFalse);
      expect(FogState.visited.isObserved, isFalse);
      expect(FogState.detected.isObserved, isFalse);
      expect(FogState.unknown.isObserved, isFalse);
    });

    test('isVisited is true only for hidden and observed', () {
      // States that imply the player has physically visited the cell.
      expect(FogState.visited.isVisited, isTrue);
      expect(FogState.active.isVisited, isTrue);
      // States that do NOT imply a visit.
      expect(FogState.unknown.isVisited, isFalse);
      expect(FogState.detected.isVisited, isFalse);
      expect(FogState.nearby.isVisited, isFalse);
    });

    test('density ordering is non-increasing with state index', () {
      // Higher index states have equal or lower (more transparent) fog density.
      for (var i = 0; i < FogState.values.length - 1; i++) {
        expect(
          FogState.values[i].density,
          greaterThanOrEqualTo(FogState.values[i + 1].density),
          reason: '${FogState.values[i].name} should have >= density than '
              '${FogState.values[i + 1].name}',
        );
      }
    });

    test('fromString parses all states correctly', () {
      expect(FogState.fromString('undetected'), equals(FogState.unknown));
      expect(FogState.fromString('unexplored'), equals(FogState.detected));
      expect(FogState.fromString('hidden'), equals(FogState.visited));
      expect(FogState.fromString('concealed'), equals(FogState.nearby));
      expect(FogState.fromString('observed'), equals(FogState.active));
    });

    test('toString returns state name', () {
      expect(FogState.unknown.toString(), equals('unknown'));
      expect(FogState.detected.toString(), equals('detected'));
      expect(FogState.visited.toString(), equals('visited'));
      expect(FogState.nearby.toString(), equals('nearby'));
      expect(FogState.active.toString(), equals('active'));
    });
  });
}
