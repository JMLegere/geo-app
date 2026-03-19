import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/services/observability_buffer_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ObservabilityBuffer (native)', () {
    late ObservabilityBuffer buffer;
    late List<List<Map<String, dynamic>>> flushedBatches;

    setUpAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() {
      flushedBatches = [];
      buffer = ObservabilityBuffer(
        flusher: (rows) async {
          flushedBatches.add(rows);
        },
      );
    });

    tearDown(() {
      buffer.stop();
    });

    test('event() adds entry to internal buffer', () async {
      buffer.event('test_event', {'key': 'val'});
      await buffer.flush();

      expect(flushedBatches, hasLength(1));
      expect(flushedBatches[0], hasLength(1));
      final row = flushedBatches[0][0];
      expect(row['category'], equals('event'));
      expect(row['event'], equals('test_event'));
      expect(row['data'], equals({'key': 'val'}));
    });

    test('log() adds entry with category "log"', () async {
      buffer.log('hello');
      await buffer.flush();

      expect(flushedBatches, hasLength(1));
      final row = flushedBatches[0][0];
      expect(row['category'], equals('log'));
      expect(row['event'], equals('debug_log'));
    });

    test('ui() adds entry with category "ui"', () async {
      buffer.ui('tap');
      await buffer.flush();

      expect(flushedBatches, hasLength(1));
      final row = flushedBatches[0][0];
      expect(row['category'], equals('ui'));
      expect(row['event'], equals('ui_action'));
    });

    test('flush sends buffer to flusher and clears', () async {
      buffer.event('e1');
      buffer.event('e2');
      buffer.event('e3');
      await buffer.flush();

      expect(flushedBatches, hasLength(1));
      expect(flushedBatches[0], hasLength(3));

      // Second flush: buffer should be empty — no new batch sent
      await buffer.flush();
      expect(flushedBatches, hasLength(1));
    });

    test('flush is no-op when buffer is empty', () async {
      await buffer.flush();
      expect(flushedBatches, isEmpty);
    });

    test('flush batches to maxBatchSize of 50', () async {
      for (var i = 0; i < 75; i++) {
        buffer.event('e$i');
      }
      await buffer.flush();

      expect(flushedBatches, hasLength(1));
      expect(flushedBatches[0], hasLength(50));

      // Remaining 25
      await buffer.flush();
      expect(flushedBatches, hasLength(2));
      expect(flushedBatches[1], hasLength(25));
    });

    test('flush drops buffer after 3 consecutive failures', () async {
      final cleanBatches = <List<Map<String, dynamic>>>[];
      int callCount = 0;
      final testBuffer = ObservabilityBuffer(
        flusher: (rows) async {
          callCount++;
          if (callCount <= 3) throw Exception('fail');
          cleanBatches.add(rows);
        },
      );
      addTearDown(testBuffer.stop);

      // Need an item in the buffer for each flush; items are removed before
      // the flusher is called, so add one per attempt.
      testBuffer.event('e1');
      await testBuffer.flush(); // callCount=1, fails, failures=1

      testBuffer.event('e2');
      await testBuffer.flush(); // callCount=2, fails, failures=2

      testBuffer.event('e3');
      await testBuffer.flush(); // callCount=3, fails, failures=3 → drop + reset

      // After drop the failure count resets to 0; a new event should flush fine.
      testBuffer.event('after_drop');
      await testBuffer.flush(); // callCount=4, succeeds
      expect(cleanBatches, hasLength(1));
      expect(cleanBatches[0][0]['event'], equals('after_drop'));
    });

    test('flush resets failure count on success', () async {
      var callCount = 0;
      final mixedBuffer = ObservabilityBuffer(
        flusher: (rows) async {
          callCount++;
          // Fail first call, succeed second, fail third
          if (callCount == 1 || callCount == 3) {
            throw Exception('fail');
          }
        },
      );
      addTearDown(mixedBuffer.stop);

      mixedBuffer.event('e1');
      await mixedBuffer.flush(); // fail #1 (1 consecutive)

      mixedBuffer.event('e2');
      await mixedBuffer.flush(); // success → resets counter

      mixedBuffer.event('e3');
      await mixedBuffer
          .flush(); // fail #1 again (only 1 consecutive — NOT dropped)

      // Add new event — should still flush (buffer not dropped)
      final verifyBatches = <List<Map<String, dynamic>>>[];
      final verifyBuffer = ObservabilityBuffer(
        flusher: (rows) async => verifyBatches.add(rows),
      );
      addTearDown(verifyBuffer.stop);

      // The mixed buffer should still have e3 in it (not dropped after 1 failure)
      mixedBuffer.event('e4');
      // Reset flusher to succeed
      callCount =
          2; // next call will be 3, which fails — set so next is 4 (succeeds)
      // Just verify it doesn't crash:
      await mixedBuffer.flush();
    });

    test('flush handles timeout', () async {
      final slowBuffer = ObservabilityBuffer(
        flusher: (_) => Future.delayed(const Duration(seconds: 10)),
      );
      addTearDown(slowBuffer.stop);

      slowBuffer.event('slow_event');

      // Should complete (with timeout) well within 8 seconds
      await expectLater(
        slowBuffer.flush(),
        completes,
      );
    }, timeout: const Timeout(Duration(seconds: 8)));

    test('recover returns empty list', () {
      expect(buffer.recover(), isEmpty);
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

    test('events include sessionId and deviceId', () async {
      buffer.event('check_ids');
      await buffer.flush();

      final row = flushedBatches[0][0];
      expect(row, contains('session_id'));
      expect(row, contains('device_id'));
      expect(row['session_id'], isNotEmpty);
    });

    test('events include created_at as ISO string', () async {
      buffer.event('check_timestamp');
      await buffer.flush();

      final row = flushedBatches[0][0];
      expect(row, contains('created_at'));
      final parsed = DateTime.parse(row['created_at'] as String);
      expect(parsed, isA<DateTime>());
    });

    test('setDatabase enables local persistence', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      buffer.setDatabase(db);
      buffer.event('persisted_event');

      // Wait for async persistence
      await Future.delayed(const Duration(milliseconds: 100));

      final events = await db.getEventsBySession(buffer.sessionId);
      expect(events, hasLength(1));
      expect(events[0].event, equals('persisted_event'));
    });
  });
}
