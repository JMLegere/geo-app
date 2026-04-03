import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/models/fog_state.dart';

void main() {
  group('FogState', () {
    test('density values are correct', () {
      expect(FogState.unknown.density, 1.0);
      expect(FogState.detected.density, 1.0);
      expect(FogState.nearby.density, 0.95);
      expect(FogState.explored.density, 0.5);
      expect(FogState.present.density, 0.0);
    });

    test('fromString round-trips for all current names', () {
      for (final state in FogState.values) {
        expect(FogState.fromString(state.name), state);
      }
    });

    test('fromString handles legacy name undetected → unknown', () {
      expect(FogState.fromString('undetected'), FogState.unknown);
    });

    test('fromString handles legacy name unexplored → detected', () {
      expect(FogState.fromString('unexplored'), FogState.detected);
    });

    test('fromString handles legacy name concealed → nearby', () {
      expect(FogState.fromString('concealed'), FogState.nearby);
    });

    test('fromString handles legacy name hidden → explored', () {
      expect(FogState.fromString('hidden'), FogState.explored);
    });

    test('fromString handles legacy name observed → present', () {
      expect(FogState.fromString('observed'), FogState.present);
    });

    test('fromString throws on unknown value', () {
      expect(() => FogState.fromString('invalid'), throwsArgumentError);
    });

    test('isPresent returns true only for present', () {
      expect(FogState.present.isPresent, true);
      for (final state in FogState.values.where((s) => s != FogState.present)) {
        expect(state.isPresent, false,
            reason: '${state.name} should not be present');
      }
    });

    test('isVisited returns true for explored and present only', () {
      expect(FogState.explored.isVisited, true);
      expect(FogState.present.isVisited, true);
      expect(FogState.unknown.isVisited, false);
      expect(FogState.detected.isVisited, false);
      expect(FogState.nearby.isVisited, false);
    });

    test('toString returns enum name', () {
      expect(FogState.unknown.toString(), 'unknown');
      expect(FogState.present.toString(), 'present');
    });
  });
}
