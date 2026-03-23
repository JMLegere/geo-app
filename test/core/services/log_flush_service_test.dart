import 'dart:async';

import 'package:earth_nova/core/services/log_flush_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogFlushService', () {
    group('addLines', () {
      test('empty list is a no-op — no timer armed', () {
        final svc = LogFlushService(flusher: (_) async {});
        svc.addLines([]);
        expect(svc.invariantHolds, isTrue);
        expect(svc.pendingCount, 0);
        expect(svc.hasTimer, isFalse);
      });

      test('arms debounce timer on first call', () {
        fakeAsync((async) {
          final svc = LogFlushService(flusher: (_) async {})
            ..sessionId = 'test-session';
          svc.addLines(['line1']);
          expect(svc.hasTimer, isTrue);
          expect(svc.pendingCount, 1);
          expect(svc.invariantHolds, isTrue);
        });
      });

      test('does not re-arm timer on subsequent calls', () {
        fakeAsync((async) {
          final svc = LogFlushService(flusher: (_) async {})
            ..sessionId = 'test-session';
          svc.addLines(['line1']);
          final firstTimer = svc.hasTimer;
          svc.addLines(['line2']);
          // Timer still armed, pending grew
          expect(firstTimer, isTrue);
          expect(svc.hasTimer, isTrue);
          expect(svc.pendingCount, 2);
          expect(svc.invariantHolds, isTrue);
        });
      });

      test('accumulates lines across multiple calls', () {
        fakeAsync((async) {
          final svc = LogFlushService(flusher: (_) async {})
            ..sessionId = 'test-session';
          svc.addLines(['a', 'b']);
          svc.addLines(['c']);
          svc.addLines(['d', 'e', 'f']);
          expect(svc.pendingCount, 6);
          expect(svc.invariantHolds, isTrue);
        });
      });

      test('caps at maxPending, evicting oldest', () {
        fakeAsync((async) {
          final calls = <Map<String, dynamic>>[];
          final svc = LogFlushService(
            flusher: (row) async => calls.add(row),
            maxPending: 5,
          )..sessionId = 'test-session';
          svc.addLines(['a', 'b', 'c', 'd', 'e']);
          svc.addLines(['f', 'g']);
          expect(svc.pendingCount, 5);
          // Flush to verify content — oldest evicted
          svc.flush();
          async.flushMicrotasks();
          final lines = (calls.single['lines'] as String).split('\n');
          expect(lines, ['c', 'd', 'e', 'f', 'g']);
          expect(svc.invariantHolds, isTrue);
        });
      });

      test('invariant holds after every addLines call', () {
        fakeAsync((async) {
          final svc = LogFlushService(flusher: (_) async {})
            ..sessionId = 'test-session';
          for (var i = 0; i < 100; i++) {
            svc.addLines(['line_$i']);
            expect(svc.invariantHolds, isTrue,
                reason: 'invariant violated at iteration $i');
          }
        });
      });
    });

    group('flush', () {
      test('timer fires flush after 5 seconds', () {
        fakeAsync((async) {
          final calls = <Map<String, dynamic>>[];
          final svc = LogFlushService(
            flusher: (row) async => calls.add(row),
          )..sessionId = 'test-session';
          svc.addLines(['line1', 'line2']);

          // Not yet flushed
          async.elapse(const Duration(seconds: 4));
          expect(calls, isEmpty);

          // Now flushed
          async.elapse(const Duration(seconds: 1));
          expect(calls.length, 1);
          expect(svc.invariantHolds, isTrue);
        });
      });

      test('sends joined lines with correct row shape', () {
        fakeAsync((async) {
          final calls = <Map<String, dynamic>>[];
          final svc = LogFlushService(
            flusher: (row) async => calls.add(row),
          );
          svc.sessionId = 'sess-123';
          svc.userId = 'user-456';
          svc.deviceId = 'dev-789';
          svc.addLines(['alpha', 'beta', 'gamma']);
          async.elapse(const Duration(seconds: 5));

          expect(calls.length, 1);
          final row = calls.single;
          expect(row['session_id'], 'sess-123');
          expect(row['user_id'], 'user-456');
          expect(row['device_id'], 'dev-789');
          expect(row['lines'], 'alpha\nbeta\ngamma');
          expect(row, contains('platform'));
          expect(row, contains('app_version'));
          expect(svc.invariantHolds, isTrue);
        });
      });

      test('clears pending and nulls timer on success', () {
        fakeAsync((async) {
          final svc = LogFlushService(flusher: (_) async {})
            ..sessionId = 'test-session';
          svc.addLines(['line1']);
          expect(svc.hasTimer, isTrue);
          expect(svc.pendingCount, 1);

          async.elapse(const Duration(seconds: 5));
          expect(svc.pendingCount, 0);
          expect(svc.hasTimer, isFalse);
          expect(svc.invariantHolds, isTrue);
        });
      });

      test('is no-op when pending is empty', () async {
        var called = false;
        final svc = LogFlushService(flusher: (_) async => called = true);
        await svc.flush();
        expect(called, isFalse);
        expect(svc.invariantHolds, isTrue);
      });

      test('skips flush when sessionId is empty (not yet wired)', () {
        fakeAsync((async) {
          final calls = <Map<String, dynamic>>[];
          final svc = LogFlushService(
            flusher: (row) async => calls.add(row),
          );
          // sessionId defaults to '' — not yet set by provider
          svc.addLines(['line1']);
          async.elapse(const Duration(seconds: 5));
          // Flush should be skipped — sessionId is empty
          expect(calls, isEmpty);
          // Timer re-arms since pending is still non-empty
          expect(svc.hasTimer, isTrue);
          expect(svc.invariantHolds, isTrue);

          // Once sessionId is set, next timer fires successfully
          svc.sessionId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
          async.elapse(const Duration(seconds: 5));
          expect(calls.length, 1);
          expect(svc.invariantHolds, isTrue);
        });
      });

      test('includes phone_number in row when set', () {
        fakeAsync((async) {
          final calls = <Map<String, dynamic>>[];
          final svc = LogFlushService(
            flusher: (row) async => calls.add(row),
          );
          svc.sessionId = 'test-session';
          svc.phoneNumber = '+15551234567';
          svc.addLines(['line1']);
          async.elapse(const Duration(seconds: 5));
          expect(calls.single['phone_number'], '+15551234567');
          expect(svc.invariantHolds, isTrue);
        });
      });

      test('cancels armed timer before sending', () {
        fakeAsync((async) {
          final calls = <Map<String, dynamic>>[];
          final svc = LogFlushService(
            flusher: (row) async => calls.add(row),
          )..sessionId = 'test-session';
          svc.addLines(['line1']);
          expect(svc.hasTimer, isTrue);

          // Manual flush cancels timer
          svc.flush();
          async.flushMicrotasks();
          expect(svc.hasTimer, isFalse);
          expect(calls.length, 1);
          expect(svc.invariantHolds, isTrue);

          // Elapse past the original timer — should NOT fire again
          async.elapse(const Duration(seconds: 10));
          expect(calls.length, 1);
        });
      });

      test('manual flush resets to idle state', () async {
        final svc = LogFlushService(flusher: (_) async {})
          ..sessionId = 'test-session';
        svc.addLines(['line1', 'line2']);
        await svc.flush();
        expect(svc.pendingCount, 0);
        expect(svc.hasTimer, isFalse);
        expect(svc.invariantHolds, isTrue);
      });

      test('invariant holds after flush completes', () {
        fakeAsync((async) {
          final svc = LogFlushService(flusher: (_) async {})
            ..sessionId = 'test-session';
          svc.addLines(['a', 'b', 'c']);
          async.elapse(const Duration(seconds: 5));
          expect(svc.invariantHolds, isTrue);
        });
      });
    });

    group('concurrent safety', () {
      test('flush is no-op when already flushing', () {
        fakeAsync((async) {
          final completer = Completer<void>();
          var callCount = 0;
          final svc = LogFlushService(
            flusher: (_) {
              callCount++;
              return completer.future;
            },
          )..sessionId = 'test-session';
          svc.addLines(['line1']);
          async.elapse(const Duration(seconds: 5)); // timer fires flush
          expect(callCount, 1);

          // Manual flush during in-flight HTTP — should be no-op
          svc.flush();
          async.flushMicrotasks();
          expect(callCount, 1); // still 1, not 2

          completer.complete();
          async.flushMicrotasks();
          expect(svc.invariantHolds, isTrue);
        });
      });

      test('lines arriving during flush are queued and timer re-armed', () {
        fakeAsync((async) {
          final completer = Completer<void>();
          final calls = <Map<String, dynamic>>[];
          final svc = LogFlushService(
            flusher: (row) {
              calls.add(row);
              if (calls.length == 1) return completer.future;
              return Future.value();
            },
          )..sessionId = 'test-session';

          svc.addLines(['batch1']);
          async.elapse(const Duration(seconds: 5)); // timer fires, flush starts
          expect(calls.length, 1);
          expect(calls[0]['lines'], 'batch1');

          // Lines arrive during flush — _flushing is true so timer not armed
          // yet, but invariant holds because _flushing guards the pending lines.
          svc.addLines(['batch2a', 'batch2b']);
          expect(svc.pendingCount, 2);
          expect(svc.invariantHolds, isTrue);

          // Complete the first flush — finally block re-arms timer
          completer.complete();
          async.flushMicrotasks();
          expect(svc.hasTimer, isTrue, reason: 'finally should re-arm timer');

          // The re-armed timer should fire and flush the new lines
          async.elapse(const Duration(seconds: 5));
          expect(calls.length, 2);
          expect(calls[1]['lines'], 'batch2a\nbatch2b');
          expect(svc.invariantHolds, isTrue);
        });
      });

      test('timer firing during slow flush — finally block re-arms', () {
        fakeAsync((async) {
          final completer = Completer<void>();
          final calls = <Map<String, dynamic>>[];
          final svc = LogFlushService(
            flusher: (row) {
              calls.add(row);
              if (calls.length == 1) return completer.future;
              return Future.value();
            },
          )..sessionId = 'test-session';

          // Start first flush
          svc.addLines(['batch1']);
          async.elapse(const Duration(seconds: 5));
          expect(calls.length, 1);

          // Lines arrive during flush — invariant holds via _flushing guard
          svc.addLines(['batch2']);
          expect(svc.invariantHolds, isTrue);

          // First flush completes — finally block should re-arm timer
          completer.complete();
          async.flushMicrotasks();

          expect(svc.pendingCount, greaterThan(0));
          expect(svc.hasTimer, isTrue,
              reason: 'finally block should re-arm for pending lines');

          // Re-armed timer fires and flushes the queued lines
          async.elapse(const Duration(seconds: 5));
          expect(calls.length, 2);
          expect(calls[1]['lines'], 'batch2');
          expect(svc.invariantHolds, isTrue);
        });
      });

      test('rapid addLines + flush interleaving never violates invariant', () {
        fakeAsync((async) {
          final svc = LogFlushService(flusher: (_) async {})
            ..sessionId = 'test-session';

          for (var i = 0; i < 50; i++) {
            svc.addLines(['line_$i']);
            expect(svc.invariantHolds, isTrue,
                reason: 'violated after addLines at iteration $i');

            if (i % 7 == 0) {
              svc.flush();
              async.flushMicrotasks();
              expect(svc.invariantHolds, isTrue,
                  reason: 'violated after flush at iteration $i');
            }
            if (i % 13 == 0) {
              async.elapse(const Duration(seconds: 5));
              expect(svc.invariantHolds, isTrue,
                  reason: 'violated after timer at iteration $i');
            }
          }

          // Drain everything
          async.elapse(const Duration(seconds: 10));
          expect(svc.pendingCount, 0);
          expect(svc.invariantHolds, isTrue);
        });
      });
    });

    group('error handling', () {
      test('flusher exception retries on next timer — pending NOT cleared', () {
        fakeAsync((async) {
          var callCount = 0;
          final svc = LogFlushService(
            flusher: (_) {
              callCount++;
              if (callCount == 1) throw Exception('network error');
              return Future.value();
            },
          )..sessionId = 'test-session';

          svc.addLines(['line1']);
          async.elapse(const Duration(seconds: 5)); // first flush — fails
          expect(callCount, 1);
          // Pending NOT cleared — lines kept for retry
          expect(svc.pendingCount, greaterThan(0));
          // Timer re-armed for retry
          expect(svc.hasTimer, isTrue);
          expect(svc.invariantHolds, isTrue);

          // Second attempt succeeds
          async.elapse(const Duration(seconds: 5));
          expect(callCount, 2);
          expect(svc.pendingCount, 0);
          expect(svc.invariantHolds, isTrue);
        });
      });

      test('3 consecutive failures drops pending with debugPrint', () {
        fakeAsync((async) {
          final debugMessages = <String>[];
          final originalDebugPrint = debugPrint;
          debugPrint = (String? message, {int? wrapWidth}) {
            if (message != null) debugMessages.add(message);
          };
          addTearDown(() => debugPrint = originalDebugPrint);

          final svc = LogFlushService(
            flusher: (_) => throw Exception('persistent failure'),
          )..sessionId = 'test-session';

          svc.addLines(['doomed']);
          // 3 consecutive failures
          async.elapse(const Duration(seconds: 5)); // attempt 1
          async.elapse(const Duration(seconds: 5)); // attempt 2
          async.elapse(const Duration(seconds: 5)); // attempt 3

          expect(svc.pendingCount, 0, reason: 'pending should be dropped');
          expect(debugMessages.any((m) => m.contains('dropping')), isTrue,
              reason: 'should log a warning about dropped lines');
          expect(svc.invariantHolds, isTrue);
        });
      });

      test('successful flush after failure resets failure counter', () {
        fakeAsync((async) {
          var callCount = 0;
          final svc = LogFlushService(
            flusher: (_) {
              callCount++;
              // Fail on 1st, succeed on 2nd, fail on 3rd, succeed on 4th
              if (callCount == 1 || callCount == 3) {
                throw Exception('transient');
              }
              return Future.value();
            },
          )..sessionId = 'test-session';

          // First batch: fail then succeed
          svc.addLines(['batch1']);
          async.elapse(const Duration(seconds: 5)); // fail
          async.elapse(const Duration(seconds: 5)); // succeed
          expect(svc.pendingCount, 0);

          // Second batch: fail then succeed (counter was reset)
          svc.addLines(['batch2']);
          async.elapse(const Duration(seconds: 5)); // fail
          async.elapse(const Duration(seconds: 5)); // succeed
          expect(svc.pendingCount, 0);

          // If counter hadn't reset, 3rd failure would have dropped lines
          expect(callCount, 4);
          expect(svc.invariantHolds, isTrue);
        });
      });

      test('retry-putback caps pending at maxPending', () {
        fakeAsync((async) {
          var callCount = 0;
          final svc = LogFlushService(
            flusher: (_) {
              callCount++;
              if (callCount == 1) throw Exception('fail');
              return Future.value();
            },
            maxPending: 10,
          );
          svc.sessionId = 'test';

          // Fill to capacity
          svc.addLines(List.generate(10, (i) => 'old_$i'));
          async.elapse(const Duration(seconds: 5)); // flush fails, putback

          // Lines arrived during the failed flush
          svc.addLines(List.generate(5, (i) => 'new_$i'));

          // Pending should be capped at maxPending, not 10 + 5
          expect(svc.pendingCount, lessThanOrEqualTo(10));
          expect(svc.invariantHolds, isTrue);
        });
      });

      test('flushing flag always resets even on exception', () async {
        var callCount = 0;
        final svc = LogFlushService(
          flusher: (_) {
            callCount++;
            if (callCount == 1) throw Exception('boom');
            return Future.value();
          },
        )..sessionId = 'test-session';
        svc.addLines(['line1']);
        await svc.flush(); // fails — flag must still reset
        // Should be able to flush again (not stuck in _flushing = true)
        expect(svc.pendingCount, greaterThan(0)); // retry kept lines
        await svc.flush(); // succeeds on second attempt
        expect(callCount, 2);
        expect(svc.pendingCount, 0);
        expect(svc.invariantHolds, isTrue);
      });
    });

    group('lifecycle', () {
      test('dispose cancels timer and sets disposed flag', () {
        fakeAsync((async) {
          final calls = <Map<String, dynamic>>[];
          final svc = LogFlushService(
            flusher: (row) async => calls.add(row),
          )..sessionId = 'test-session';
          svc.addLines(['line1']);
          expect(svc.hasTimer, isTrue);

          svc.dispose();
          expect(svc.hasTimer, isFalse);

          // Timer should not fire after dispose
          async.elapse(const Duration(seconds: 10));
          expect(calls, isEmpty);
        });
      });

      test('addLines after dispose asserts in debug, no-op in release', () {
        fakeAsync((async) {
          final svc = LogFlushService(flusher: (_) async {});
          svc.dispose();

          // In debug mode, assert fires
          expect(
            () => svc.addLines(['late line']),
            throwsA(isA<AssertionError>()),
          );
          // Pending should not have grown
          expect(svc.pendingCount, 0);
        });
      });

      test('flush after dispose is no-op', () async {
        var called = false;
        final svc = LogFlushService(flusher: (_) async => called = true);
        svc.addLines(['line1']);
        svc.dispose();
        await svc.flush();
        expect(called, isFalse);
      });

      test('dispose during in-flight flush — flush completes, no re-arm', () {
        fakeAsync((async) {
          final completer = Completer<void>();
          final calls = <Map<String, dynamic>>[];
          final svc = LogFlushService(
            flusher: (row) {
              calls.add(row);
              return completer.future;
            },
          )..sessionId = 'test-session';

          svc.addLines(['line1']);
          async.elapse(const Duration(seconds: 5)); // flush starts
          expect(calls.length, 1);

          // Lines arrive during flush
          svc.addLines(['line2']);

          // Dispose while flush is in flight
          svc.dispose();

          // Complete the flush
          completer.complete();
          async.flushMicrotasks();

          // Should NOT re-arm timer (disposed)
          expect(svc.hasTimer, isFalse);
          // Pending lines from during flush are orphaned — acceptable
          async.elapse(const Duration(seconds: 10));
          expect(calls.length, 1); // no second flush
        });
      });
    });
  });
}
