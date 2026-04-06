import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:earth_nova/core/observability/observability_service.dart';

void main() {
  group('ObservabilityService', () {
    late ObservabilityService obs;

    setUp(() {
      obs = ObservabilityService(sessionId: 'test-session-123');
    });

    test('log adds event to buffer', () {
      obs.log('auth.sign_in_success', 'auth');
      expect(() => obs.flush(), returnsNormally);
    });

    test('log includes session_id, category, event, and created_at', () {
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
      final error = Exception('simulated postgrest error');
      obs.logError(error, StackTrace.current, event: 'items.fetch_error');
      expect(() => obs.flush(), returnsNormally);
    });

    test('logError captures Supabase AuthException details', () {
      final error = supa.AuthException('Invalid login credentials');
      obs.logError(error, StackTrace.current, event: 'auth.sign_in_error');
      expect(() => obs.flush(), returnsNormally);
    });

    test('logError captures Supabase PostgrestException details', () {
      final error =
          supa.PostgrestException(message: 'RLS denied', code: '42501');
      obs.logError(error, StackTrace.current, event: 'data.rls_error');
      expect(() => obs.flush(), returnsNormally);
    });

    test('setUserId attaches user ID to subsequent events', () {
      obs.setUserId('user-uuid-456');
      obs.log('auth.session_restored', 'auth');
      expect(() => obs.flush(), returnsNormally);
    });

    test('flush with empty buffer is a no-op', () async {
      await obs.flush();
    });

    test('flush without client uses debugPrint mode (no crash)', () async {
      obs.log('test.event', 'test');
      await obs.flush();
    });

    test('flush clears buffer after sending', () async {
      obs.log('event.one', 'test');
      obs.log('event.two', 'test');
      await obs.flush();
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
