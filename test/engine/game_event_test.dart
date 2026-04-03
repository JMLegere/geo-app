import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/engine/game_event.dart';

void main() {
  group('GameEvent', () {
    const sessionId = 'test-session-123';

    test('cellVisited has category state and correct event name', () {
      final event = GameEvent.cellVisited(
        sessionId: sessionId,
        cellId: 'v_1_2',
      );

      expect(event.category, 'state');
      expect(event.event, 'cell_visited');
      expect(event.sessionId, sessionId);
      expect(event.data['cell_id'], 'v_1_2');
      expect(event.timestamp, isA<DateTime>());
    });

    test('speciesDiscovered has category state and correct event name', () {
      final event = GameEvent.speciesDiscovered(
        sessionId: sessionId,
        cellId: 'v_1_2',
        definitionId: 'def_42',
        displayName: 'Red Fox',
        category: 'fauna',
        rarity: 'leastConcern',
        dailySeed: 'seed_abc',
        cellEventType: null,
        instance: null,
        hasEnrichment: false,
        affixCount: 0,
      );

      expect(event.category, 'state');
      expect(event.event, 'species_discovered');
      expect(event.sessionId, sessionId);
      expect(event.data['definition_id'], 'def_42');
      expect(event.data['display_name'], 'Red Fox');
    });

    test('error has category system', () {
      final event = GameEvent.error(
        sessionId: sessionId,
        message: 'Something went wrong',
        context: 'test_context',
      );

      expect(event.category, 'system');
      expect(event.event, 'error');
      expect(event.data['message'], 'Something went wrong');
      expect(event.data['context'], 'test_context');
    });

    test('gpsErrorChanged has category system', () {
      final event = GameEvent.gpsErrorChanged(
        sessionId: sessionId,
        error: 'low_accuracy',
        accuracy: 75.0,
      );

      expect(event.category, 'system');
      expect(event.event, 'gps_error_changed');
      expect(event.data['accuracy'], 75.0);
    });

    test('all events include sessionId and timestamp', () {
      final events = [
        GameEvent.cellVisited(sessionId: sessionId, cellId: 'c1'),
        GameEvent.fogChanged(
          sessionId: sessionId,
          cellId: 'c1',
          oldState: 'unknown',
          newState: 'present',
        ),
        GameEvent.explorationDisabledChanged(
          sessionId: sessionId,
          disabled: true,
        ),
      ];

      for (final event in events) {
        expect(event.sessionId, sessionId,
            reason: '${event.event} missing sessionId');
        expect(event.timestamp, isA<DateTime>(),
            reason: '${event.event} missing timestamp');
      }
    });

    test('fogChanged has category state', () {
      final event = GameEvent.fogChanged(
        sessionId: sessionId,
        cellId: 'v_3_4',
        oldState: 'unknown',
        newState: 'explored',
      );

      expect(event.category, 'state');
      expect(event.event, 'fog_changed');
      expect(event.data['old_state'], 'unknown');
      expect(event.data['new_state'], 'explored');
    });

    test('explorationDisabledChanged has category system', () {
      final event = GameEvent.explorationDisabledChanged(
        sessionId: sessionId,
        disabled: true,
      );

      expect(event.category, 'system');
      expect(event.event, 'exploration_disabled_changed');
      expect(event.data['disabled'], true);
    });

    test('toRow excludes non-primitive values from data', () {
      final event = GameEvent.speciesDiscovered(
        sessionId: sessionId,
        cellId: 'v_1_2',
        definitionId: 'def_42',
        displayName: 'Red Fox',
        category: 'fauna',
        rarity: 'leastConcern',
        dailySeed: 'seed_abc',
        cellEventType: null,
        instance: Object(), // non-primitive — should be excluded from row
        hasEnrichment: false,
        affixCount: 0,
      );

      final row = event.toRow();
      expect(row['session_id'], sessionId);
      expect(row['category'], 'state');
      // instance is Object, not a primitive — should not appear in row data
      final data = row['data'] as Map<String, dynamic>;
      expect(data.containsKey('instance'), isFalse);
      // primitive fields should be present
      expect(data['definition_id'], 'def_42');
    });
  });
}
