import 'dart:convert';

import 'package:earth_nova/core/services/observability_buffer_native.dart';
import 'package:earth_nova/core/services/startup_beacon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    StartupBeacon.resetForTest();
  });

  group('ObservabilityBuffer (unified)', () {
    late ObservabilityBuffer buffer;

    setUp(() {
      buffer = ObservabilityBuffer();
    });

    test('event() calls debugPrint with [EVENT] tag and JSON data', () {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (String? msg, {int? wrapWidth}) {
        if (msg != null) logs.add(msg);
      };
      addTearDown(() => debugPrint = original);

      buffer.event('cell_visited', {'cell_id': 'v_123', 'count': 5});

      expect(logs.length, 1);
      expect(logs[0], contains('[EVENT] cell_visited'));
      expect(logs[0], contains('"cell_id":"v_123"'));
      expect(logs[0], contains('"count":5'));
    });

    test('event() with empty data omits JSON payload', () {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (String? msg, {int? wrapWidth}) {
        if (msg != null) logs.add(msg);
      };
      addTearDown(() => debugPrint = original);

      buffer.event('simple_event');

      expect(logs.length, 1);
      expect(logs[0], equals('[EVENT] simple_event'));
    });

    test('sessionId comes from StartupBeacon', () {
      expect(buffer.sessionId, equals(StartupBeacon.sessionId));
    });

    test('userId setter rejects non-UUID strings', () {
      buffer.userId = 'not-a-uuid';
      expect(buffer.userId, isNull);
    });

    test('userId setter accepts valid UUID', () {
      const validUuid = '550e8400-e29b-41d4-a716-446655440000';
      buffer.userId = validUuid;
      expect(buffer.userId, equals(validUuid));
    });

    test('userId setter accepts null', () {
      buffer.userId = '550e8400-e29b-41d4-a716-446655440000';
      buffer.userId = null;
      expect(buffer.userId, isNull);
    });

    test('event() produces parseable JSON in the data portion', () {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (String? msg, {int? wrapWidth}) {
        if (msg != null) logs.add(msg);
      };
      addTearDown(() => debugPrint = original);

      buffer.event('test_parse', {
        'nested': {'a': 1},
        'list': [1, 2, 3]
      });

      // Extract JSON portion after event name
      final line = logs[0];
      final jsonStart = line.indexOf('{');
      expect(jsonStart, greaterThan(0));
      final jsonStr = line.substring(jsonStart);
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(parsed['nested'], equals({'a': 1}));
      expect(parsed['list'], equals([1, 2, 3]));
    });
  });
}
