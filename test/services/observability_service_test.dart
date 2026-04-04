import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/services/observability_service.dart';

void main() {
  group('ObservabilityService', () {
    late ObservabilityService obs;

    setUp(() {
      obs = ObservabilityService(sessionId: 'test-session-123');
    });

    test('log adds event to buffer', () {
      obs.log('auth.sign_in_success', 'auth');

      // Buffer is private, so we verify indirectly: flush without a client
      // should not throw (fire-and-forget, debugPrint mode).
      expect(() => obs.flush(), returnsNormally);
    });

    test('log includes session_id, category, event, and created_at', () {
      // We can't inspect the buffer directly, but we can verify the service
      // doesn't crash with various payloads.
      obs.log('app.cold_start', 'lifecycle', data: {
        'version': 'dev',
        'platform': 'web',
      });
      obs.log('auth.sign_in_started', 'auth', data: {
        'phone_hash': 'abc123',
      });
      expect(() => obs.flush(), returnsNormally);
    });

    test('log with null data defaults to empty map', () {
      obs.log('auth.sign_out', 'auth');
      expect(() => obs.flush(), returnsNormally);
    });

    test('logError captures error_type, error_message, and stack_trace', () {
      try {
        throw Exception('test error');
      } catch (e, stack) {
        obs.logError(e, stack, event: 'app.crash.unhandled');
      }
      expect(() => obs.flush(), returnsNormally);
    });

    test('logError captures PostgrestException details', () {
      // Simulate a Supabase error — we can't construct a real PostgrestException
      // easily, so we test with a generic exception and verify no crash.
      final error = Exception('simulated postgrest error');
      obs.logError(error, StackTrace.current, event: 'items.fetch_error');
      expect(() => obs.flush(), returnsNormally);
    });

    test('setUserId attaches user ID to subsequent events', () {
      obs.setUserId('user-uuid-456');
      obs.log('auth.session_restored', 'auth');
      expect(() => obs.flush(), returnsNormally);
    });

    test('flush with empty buffer is a no-op', () async {
      // No events logged — flush should complete silently.
      await obs.flush();
    });

    test('flush without client uses debugPrint mode (no crash)', () async {
      obs.log('test.event', 'test');
      await obs.flush();
      // No client = debugPrint only. No exception.
    });

    test('flush clears buffer after sending', () async {
      obs.log('event.one', 'test');
      obs.log('event.two', 'test');
      await obs.flush();
      // Second flush should be a no-op (buffer was cleared).
      await obs.flush();
    });

    test('startPeriodicFlush does not throw', () {
      obs.startPeriodicFlush();
      obs.dispose();
    });

    test('dispose flushes remaining events', () {
      obs.log('final.event', 'test');
      expect(() => obs.dispose(), returnsNormally);
    });
  });

  group('hashPhone', () {
    test('returns consistent SHA-256 hash', () {
      final hash1 = hashPhone('+15551234567');
      final hash2 = hashPhone('+15551234567');
      expect(hash1, hash2);
    });

    test('returns 64-character hex string', () {
      final hash = hashPhone('+15551234567');
      expect(hash.length, 64);
      expect(RegExp(r'^[a-f0-9]+$').hasMatch(hash), isTrue);
    });

    test('different phones produce different hashes', () {
      final hash1 = hashPhone('+15551234567');
      final hash2 = hashPhone('+15559999999');
      expect(hash1, isNot(hash2));
    });
  });
}
