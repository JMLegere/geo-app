import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/engine/game_event.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

GameEvent makeGameEvent({
  String category = 'test',
  String event = 'test_event',
  Map<String, dynamic> data = const {},
  DateTime? timestamp,
}) {
  return GameEvent(
    category: category,
    event: event,
    data: data,
    timestamp: timestamp ?? DateTime.utc(2026, 3, 15, 12, 0, 0),
  );
}

void main() {
  group('GameEvent', () {
    test('stores all constructor fields', () {
      final ts = DateTime.utc(2026, 1, 1);
      final e = GameEvent(
        category: 'state',
        event: 'cell_entered',
        data: {'cellId': 'abc'},
        timestamp: ts,
      );

      expect(e.category, equals('state'));
      expect(e.event, equals('cell_entered'));
      expect(e.data, equals({'cellId': 'abc'}));
      expect(e.timestamp, equals(ts));
    });

    test('data defaults to empty map when not provided', () {
      final e = GameEvent(
        category: 'state',
        event: 'tick',
        timestamp: DateTime.now(),
      );

      expect(e.data, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Factory constructors
  // ---------------------------------------------------------------------------

  group('GameEvent.state', () {
    test('sets category to state', () {
      final e = GameEvent.state('cell_entered');
      expect(e.category, equals('state'));
      expect(e.event, equals('cell_entered'));
    });

    test('sets timestamp to approximately now', () {
      final before = DateTime.now();
      final e = GameEvent.state('tick');
      final after = DateTime.now();

      expect(e.timestamp.isAfter(before) || e.timestamp == before, isTrue);
      expect(e.timestamp.isBefore(after) || e.timestamp == after, isTrue);
    });

    test('data defaults to empty map', () {
      final e = GameEvent.state('tick');
      expect(e.data, isEmpty);
    });

    test('accepts data map', () {
      final e = GameEvent.state('cell_entered', {'cellId': 'v_1_2'});
      expect(e.data, equals({'cellId': 'v_1_2'}));
    });
  });

  group('GameEvent.user', () {
    test('sets category to user', () {
      final e = GameEvent.user('tap_cell');
      expect(e.category, equals('user'));
      expect(e.event, equals('tap_cell'));
    });

    test('sets timestamp to approximately now', () {
      final before = DateTime.now();
      final e = GameEvent.user('tap_cell');
      final after = DateTime.now();

      expect(e.timestamp.isAfter(before) || e.timestamp == before, isTrue);
      expect(e.timestamp.isBefore(after) || e.timestamp == after, isTrue);
    });

    test('accepts data map', () {
      final e = GameEvent.user('tap_cell', {'x': 10, 'y': 20});
      expect(e.data, equals({'x': 10, 'y': 20}));
    });
  });

  group('GameEvent.system', () {
    test('sets category to system', () {
      final e = GameEvent.system('app_start');
      expect(e.category, equals('system'));
      expect(e.event, equals('app_start'));
    });

    test('sets timestamp to approximately now', () {
      final before = DateTime.now();
      final e = GameEvent.system('app_start');
      final after = DateTime.now();

      expect(e.timestamp.isAfter(before) || e.timestamp == before, isTrue);
      expect(e.timestamp.isBefore(after) || e.timestamp == after, isTrue);
    });

    test('accepts data map', () {
      final e = GameEvent.system('error', {'msg': 'timeout'});
      expect(e.data, equals({'msg': 'timeout'}));
    });
  });

  group('GameEvent.performance', () {
    test('sets category to performance', () {
      final e = GameEvent.performance('frame_drop');
      expect(e.category, equals('performance'));
      expect(e.event, equals('frame_drop'));
    });

    test('sets timestamp to approximately now', () {
      final before = DateTime.now();
      final e = GameEvent.performance('frame_drop');
      final after = DateTime.now();

      expect(e.timestamp.isAfter(before) || e.timestamp == before, isTrue);
      expect(e.timestamp.isBefore(after) || e.timestamp == after, isTrue);
    });

    test('accepts data map', () {
      final e = GameEvent.performance('render', {'ms': 16});
      expect(e.data, equals({'ms': 16}));
    });
  });

  // ---------------------------------------------------------------------------
  // toRow()
  // ---------------------------------------------------------------------------

  group('GameEvent.toRow', () {
    test('includes all envelope fields', () {
      final ts = DateTime.utc(2026, 3, 15, 10, 30, 0);
      final e = makeGameEvent(
        category: 'state',
        event: 'cell_entered',
        data: {'cellId': 'v_1_2'},
        timestamp: ts,
      );

      final row = e.toRow(
        sessionId: 'session-123',
        userId: 'user-abc',
        deviceId: 'device-xyz',
      );

      expect(row['session_id'], equals('session-123'));
      expect(row['user_id'], equals('user-abc'));
      expect(row['device_id'], equals('device-xyz'));
      expect(row['category'], equals('state'));
      expect(row['event'], equals('cell_entered'));
      expect(row['data'], equals({'cellId': 'v_1_2'}));
      expect(row.containsKey('created_at'), isTrue);
    });

    test('includes null userId when not provided', () {
      final e = makeGameEvent();
      final row = e.toRow(
        sessionId: 'session-123',
        deviceId: 'device-xyz',
      );

      expect(row.containsKey('user_id'), isTrue);
      expect(row['user_id'], isNull);
    });

    test('created_at is UTC ISO 8601 string', () {
      final ts = DateTime.utc(2026, 3, 15, 10, 30, 0);
      final e = makeGameEvent(timestamp: ts);
      final row = e.toRow(
        sessionId: 's',
        userId: 'u',
        deviceId: 'd',
      );

      final createdAt = row['created_at'] as String;
      expect(createdAt, equals('2026-03-15T10:30:00.000Z'));
    });

    test('created_at converts local timestamp to UTC', () {
      // Create a non-UTC timestamp and verify toRow converts it.
      final localTs = DateTime(2026, 6, 1, 14, 0, 0);
      final e = makeGameEvent(timestamp: localTs);
      final row = e.toRow(
        sessionId: 's',
        userId: 'u',
        deviceId: 'd',
      );

      final createdAt = row['created_at'] as String;
      // The string should end with 'Z' indicating UTC.
      expect(createdAt, endsWith('Z'));
      // Parse it back to verify it's a valid ISO 8601 string.
      expect(() => DateTime.parse(createdAt), returnsNormally);
    });

    test('row has exactly 7 keys', () {
      final e = makeGameEvent();
      final row = e.toRow(
        sessionId: 's',
        userId: 'u',
        deviceId: 'd',
      );

      expect(row.length, equals(7));
    });
  });

  // ---------------------------------------------------------------------------
  // toString()
  // ---------------------------------------------------------------------------

  group('GameEvent.toString', () {
    test('includes category and event', () {
      final e = makeGameEvent(category: 'state', event: 'cell_entered');
      final str = e.toString();

      expect(str, contains('state'));
      expect(str, contains('cell_entered'));
    });

    test('includes data field count', () {
      final e = makeGameEvent(data: {'a': 1, 'b': 2, 'c': 3});
      final str = e.toString();

      expect(str, contains('3 fields'));
    });

    test('shows 0 fields for empty data', () {
      final e = makeGameEvent(data: {});
      final str = e.toString();

      expect(str, contains('0 fields'));
    });

    test('matches expected format', () {
      final e = makeGameEvent(
        category: 'user',
        event: 'tap',
        data: {'x': 1},
      );

      expect(e.toString(), equals('GameEvent(user/tap, 1 fields)'));
    });
  });
}
