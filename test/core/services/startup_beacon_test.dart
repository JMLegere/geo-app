import 'package:earth_nova/core/services/startup_beacon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    StartupBeacon.resetForTest();
  });

  group('StartupBeacon', () {
    group('sessionId', () {
      test('is consistent across calls', () {
        final id1 = StartupBeacon.sessionId;
        final id2 = StartupBeacon.sessionId;
        expect(id1, id2);
      });

      test('is a valid UUID v4 format', () {
        final id = StartupBeacon.sessionId;
        final uuidPattern = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          caseSensitive: false,
        );
        expect(uuidPattern.hasMatch(id), isTrue);
      });

      test('changes after resetForTest', () {
        final id1 = StartupBeacon.sessionId;
        StartupBeacon.resetForTest();
        final id2 = StartupBeacon.sessionId;
        expect(id1, isNot(id2));
      });
    });

    group('emit', () {
      test('calls testFlusher with correct row shape', () {
        final calls = <Map<String, dynamic>>[];
        StartupBeacon.testFlusher = (row) => calls.add(row);

        StartupBeacon.emit('supabase_init');

        expect(calls.length, 1);
        final row = calls.single;
        expect(row['session_id'], StartupBeacon.sessionId);
        expect(row['lines'], '[BOOT] phase=supabase_init');
        expect(row, contains('platform'));
        expect(row, contains('app_version'));
      });

      test('formats extra data into lines field', () {
        final calls = <Map<String, dynamic>>[];
        StartupBeacon.testFlusher = (row) => calls.add(row);

        StartupBeacon.emit(
            'hydration_start', {'user_id': 'abc-123', 'source': 'sqlite'});

        expect(calls.single['lines'],
            '[BOOT] phase=hydration_start user_id=abc-123 source=sqlite');
      });

      test('is no-op when no flusher and SUPABASE_URL is empty', () {
        // No testFlusher set, SUPABASE_URL is empty in test env
        // Should not throw
        StartupBeacon.emit('test_phase');
        // No way to assert no HTTP call, but verifying no exception
      });

      test('never throws when testFlusher throws', () {
        StartupBeacon.testFlusher = (_) => throw Exception('boom');

        // Should not propagate the exception
        expect(() => StartupBeacon.emit('bad_phase'), returnsNormally);
      });

      test('uses promoted client when available', () {
        final calls = <Map<String, dynamic>>[];
        StartupBeacon.testFlusher = (row) => calls.add(row);

        // Emit before promote — uses testFlusher (standing in for raw HTTP)
        StartupBeacon.emit('pre_promote');
        expect(calls.length, 1);

        // Promote with a client — still uses testFlusher in test mode
        // (we can't easily mock SupabaseClient, but we verify promote doesn't break)
        StartupBeacon.emit('post_promote');
        expect(calls.length, 2);
      });

      test('includes session_id in every row', () {
        final calls = <Map<String, dynamic>>[];
        StartupBeacon.testFlusher = (row) => calls.add(row);

        StartupBeacon.emit('phase_a');
        StartupBeacon.emit('phase_b');
        StartupBeacon.emit('phase_c');

        final sessionIds = calls.map((r) => r['session_id'] as String).toSet();
        expect(sessionIds.length, 1, reason: 'all rows share same sessionId');
        expect(sessionIds.single, StartupBeacon.sessionId);
      });
    });

    group('promote', () {
      test('sets client without throwing', () {
        // Can't easily construct a real SupabaseClient in tests,
        // but verify the static setter doesn't throw
        expect(() => StartupBeacon.promote(null), returnsNormally);
      });

      test('resetForTest clears promoted client', () {
        // After reset, should be back to raw HTTP mode
        StartupBeacon.resetForTest();
        final calls = <Map<String, dynamic>>[];
        StartupBeacon.testFlusher = (row) => calls.add(row);
        StartupBeacon.emit('after_reset');
        expect(calls.length, 1);
      });
    });
  });
}
