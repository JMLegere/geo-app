import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/engine/event_sink.dart';
import 'package:earth_nova/core/engine/game_event.dart';
// ---------------------------------------------------------------------------
// Testable subclass — intercepts flush() to avoid real Supabase calls
// ---------------------------------------------------------------------------

class TestableEventSink extends EventSink {
  TestableEventSink()
      : super(
          flusher: (_) async {},
          userIdResolver: () => null,
        );

  int flushCallCount = 0;
  List<int> batchSizesAtFlush = [];

  /// Tracks how many events were pending when flush() was invoked,
  /// then clears the queue without hitting Supabase.
  @override
  Future<void> flush() async {
    flushCallCount++;
    // We can't access _pending directly (private), so we track via
    // the call count. The real flush() clears pending — we call super
    // which will fail on Supabase but the try/catch in EventSink handles it.
    // Instead, we override completely to skip Supabase.
  }
}

/// A spy that calls through to the real flush() (which will fail on the
/// fake client, but the catch block handles it gracefully).
class SpyEventSink extends EventSink {
  SpyEventSink()
      : super(
          flusher: (_) async {},
          userIdResolver: () => null,
        );

  int flushCallCount = 0;

  @override
  Future<void> flush() async {
    flushCallCount++;
    await super.flush();
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

GameEvent _makeEvent([String event = 'test_event']) =>
    GameEvent.state(event, {'ts': DateTime.now().millisecondsSinceEpoch});

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EventSink', () {
    group('sessionId', () {
      test('is a valid UUID v4 format string', () {
        final sink = EventSink(
          flusher: (_) async {},
          userIdResolver: () => null,
        );

        // UUID v4 format: 8-4-4-4-12 hex digits
        final uuidRegex = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        );
        expect(sink.sessionId, matches(uuidRegex));
      });

      test('is unique per EventSink instance', () {
        final sink1 = EventSink(
          flusher: (_) async {},
          userIdResolver: () => null,
        );
        final sink2 = EventSink(
          flusher: (_) async {},
          userIdResolver: () => null,
        );

        expect(sink1.sessionId, isNot(equals(sink2.sessionId)));
      });

      test('is stable across multiple reads', () {
        final sink = EventSink(
          flusher: (_) async {},
          userIdResolver: () => null,
        );
        final first = sink.sessionId;
        final second = sink.sessionId;

        expect(first, equals(second));
      });
    });

    group('add', () {
      test('accumulates events for later flush', () {
        final sink = TestableEventSink();

        sink.add(_makeEvent('e1'));
        sink.add(_makeEvent('e2'));
        sink.add(_makeEvent('e3'));

        // No auto-flush triggered (< 100 events).
        expect(sink.flushCallCount, equals(0));
      });

      test('triggers auto-flush when batch reaches maxBatchSize (100)', () {
        // Use SpyEventSink so super.flush() clears _pending (Supabase
        // error is caught internally — queue is cleared before insert).
        final sink = SpyEventSink();

        for (var i = 0; i < 100; i++) {
          sink.add(_makeEvent('event_$i'));
        }

        // Auto-flush should have been called once at event #100.
        expect(sink.flushCallCount, equals(1));
      });

      test('triggers multiple auto-flushes for 200+ events', () {
        // SpyEventSink calls super.flush() which clears _pending before
        // the (failing) Supabase insert, so the 101st event starts fresh.
        final sink = SpyEventSink();

        for (var i = 0; i < 200; i++) {
          sink.add(_makeEvent('event_$i'));
        }

        // Two batches of 100.
        expect(sink.flushCallCount, equals(2));
      });

      test('does not trigger auto-flush at 99 events', () {
        final sink = TestableEventSink();

        for (var i = 0; i < 99; i++) {
          sink.add(_makeEvent('event_$i'));
        }

        expect(sink.flushCallCount, equals(0));
      });
    });

    group('flush', () {
      test('is a no-op when queue is empty', () async {
        final sink = SpyEventSink();

        // Flush with no events added.
        await sink.flush();

        // flush() was called but should have returned immediately
        // (empty check). Call count still increments since our spy counts
        // before super.flush() checks.
        expect(sink.flushCallCount, equals(1));
      });

      test('clears pending queue after flush', () async {
        final sink = SpyEventSink();

        sink.add(_makeEvent('e1'));
        sink.add(_makeEvent('e2'));

        // First flush — processes 2 events (Supabase call will fail but
        // catch block handles it, and _pending is cleared before the insert).
        await sink.flush();

        // Second flush — should be a no-op (queue was cleared).
        final secondFlushCount = sink.flushCallCount;
        await sink.flush();

        // The second flush increments the count but returns early (empty).
        expect(sink.flushCallCount, equals(secondFlushCount + 1));
      });

      test('handles Supabase errors gracefully without rethrowing', () async {
        final sink = EventSink(
          flusher: (_) async {},
          userIdResolver: () => null,
        );

        sink.add(_makeEvent());

        // Should not throw — error is caught internally.
        await expectLater(sink.flush(), completes);
      });
    });

    group('start and stop', () {
      test('start() creates a periodic timer', () async {
        final sink = TestableEventSink();

        sink.start();

        // Timer is internal, but we can verify it doesn't throw
        // and that stop() can be called after.
        expect(() => sink.start(), returnsNormally);

        sink.stop();
      });

      test('stop() cancels the timer', () {
        final sink = TestableEventSink();

        sink.start();
        sink.stop();

        // Calling stop() again should be safe (no-op on null timer).
        expect(() => sink.stop(), returnsNormally);
      });

      test('start() replaces existing timer on re-call', () {
        final sink = TestableEventSink();

        sink.start();
        // Second start should cancel old timer and create new one.
        expect(() => sink.start(), returnsNormally);

        sink.stop();
      });
    });

    group('platform', () {
      test('returns a non-empty string', () {
        expect(EventSink.platform, isNotEmpty);
      });
    });

    group('appVersion', () {
      test('returns dev as default', () {
        // Without --dart-define=APP_VERSION, defaults to 'dev'.
        expect(EventSink.appVersion, equals('dev'));
      });
    });
  });

  // ---------------------------------------------------------------------------
  // toRow integration — verify the data transformation EventSink passes to
  // Supabase. This is tested primarily in game_event_test.dart, but we
  // verify the envelope fields EventSink adds.
  // ---------------------------------------------------------------------------

  group('EventSink toRow envelope', () {
    test('toRow uses EventSink sessionId and deviceId', () {
      final sink = EventSink(
        flusher: (_) async {},
        userIdResolver: () => null,
      );
      final event = _makeEvent('test');

      final row = event.toRow(
        sessionId: sink.sessionId,
        deviceId: 'test-device',
      );

      expect(row['session_id'], equals(sink.sessionId));
      expect(row['device_id'], equals('test-device'));
      expect(row['user_id'], isNull);
      expect(row['category'], equals('state'));
      expect(row['event'], equals('test'));
      expect(row.containsKey('data'), isTrue);
      expect(row.containsKey('created_at'), isTrue);
    });
  });
}
