import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/fog_state.dart';

void main() {
  group('FogState', () {
    test('all 5 states exist', () {
      expect(FogState.unknown, isNotNull);
      expect(FogState.detected, isNotNull);
      expect(FogState.explored, isNotNull);
      expect(FogState.nearby, isNotNull);
      expect(FogState.present, isNotNull);
    });

    test('density mapping is correct', () {
      expect(FogState.unknown.density, equals(1.0));
      expect(FogState.detected.density, equals(0.85));
      expect(FogState.nearby.density, equals(0.95));
      expect(FogState.explored.density, equals(0.5));
      expect(FogState.present.density, equals(0.0));
    });

    test('isCurrent is true only for current state', () {
      expect(FogState.present.isPresent, isTrue);
      expect(FogState.nearby.isPresent, isFalse);
      expect(FogState.explored.isPresent, isFalse);
      expect(FogState.detected.isPresent, isFalse);
      expect(FogState.unknown.isPresent, isFalse);
    });

    test('isVisited is true only for explored and current', () {
      // States that imply the player has physically visited the cell.
      expect(FogState.explored.isVisited, isTrue);
      expect(FogState.present.isVisited, isTrue);
      // States that do NOT imply a visit.
      expect(FogState.unknown.isVisited, isFalse);
      expect(FogState.detected.isVisited, isFalse);
      expect(FogState.nearby.isVisited, isFalse);
    });

    test('all densities are within valid [0.0, 1.0] range', () {
      // Note: enum declaration order does NOT match fog density order.
      // detected (0.85) is intentionally MORE visible than nearby (0.95) —
      // detected cells show district shape clearly under lighter fog.
      for (final state in FogState.values) {
        expect(
          state.density,
          inInclusiveRange(0.0, 1.0),
          reason: '${state.name}.density must be in [0.0, 1.0]',
        );
      }
    });

    test('fromString parses legacy names for backward compatibility', () {
      expect(FogState.fromString('undetected'), equals(FogState.unknown));
      expect(FogState.fromString('unexplored'), equals(FogState.detected));
      expect(FogState.fromString('hidden'), equals(FogState.explored));
      expect(FogState.fromString('concealed'), equals(FogState.nearby));
      expect(FogState.fromString('observed'), equals(FogState.present));
    });

    test('fromString parses new names correctly', () {
      expect(FogState.fromString('unknown'), equals(FogState.unknown));
      expect(FogState.fromString('detected'), equals(FogState.detected));
      expect(FogState.fromString('explored'), equals(FogState.explored));
      expect(FogState.fromString('nearby'), equals(FogState.nearby));
      expect(FogState.fromString('present'), equals(FogState.present));
    });

    test('toString returns new state name', () {
      expect(FogState.unknown.toString(), equals('unknown'));
      expect(FogState.detected.toString(), equals('detected'));
      expect(FogState.explored.toString(), equals('explored'));
      expect(FogState.nearby.toString(), equals('nearby'));
      expect(FogState.present.toString(), equals('present'));
    });
  });
}
