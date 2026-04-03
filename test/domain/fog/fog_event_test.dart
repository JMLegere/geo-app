import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/domain/fog/fog_event.dart';
import 'package:earth_nova/models/fog_state.dart';

void main() {
  group('FogStateChangedEvent', () {
    test('stores cellId and fogState fields', () {
      final event = FogStateChangedEvent(
        cellId: 'cell_1',
        oldState: FogState.unknown,
        newState: FogState.present,
      );

      expect(event.cellId, 'cell_1');
      expect(event.oldState, FogState.unknown);
      expect(event.newState, FogState.present);
    });

    test('uses provided timestamp when supplied', () {
      final ts = DateTime(2026, 1, 15, 12, 0, 0);
      final event = FogStateChangedEvent(
        cellId: 'cell_x',
        oldState: FogState.detected,
        newState: FogState.explored,
        timestamp: ts,
      );

      expect(event.timestamp, ts);
    });

    test('toString produces readable output containing cellId and states', () {
      final event = FogStateChangedEvent(
        cellId: 'cell_42',
        oldState: FogState.unknown,
        newState: FogState.present,
      );

      final str = event.toString();
      expect(str, contains('cell_42'));
      expect(str, contains('unknown'));
      expect(str, contains('present'));
    });
  });
}
