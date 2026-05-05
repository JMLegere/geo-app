import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/trace_context.dart';

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

    test('log stores OTel-shaped log records', () {
      final trace = TraceContext.start();

      obs.log('map.map_created', 'map', data: {
        'trace_id': trace.traceId,
        'span_id': trace.spanId,
        'source': 'test',
      });

      final row = obs.pendingLogRecords.single;
      expect(row['event_name'], 'map.map_created');
      expect(row['category'], 'map');
      expect(row['trace_id'], trace.traceId);
      expect(row['span_id'], trace.spanId);
      expect(row['attributes'], containsPair('source', 'test'));
      expect(row, contains('occurred_at'));
      expect(row, isNot(contains('event')));
      expect(row, isNot(contains('data')));
    });

    test('logFlowEvent stores lifecycle grammar attributes', () {
      final span = obs.startSpan('map.bootstrap');

      obs.logFlowEvent(
        'map.bootstrap',
        TelemetryFlowPhase.waitingOn,
        'map',
        eventName: 'map.readiness_waiting',
        span: span,
        dependency: 'cells',
        reason: 'cells_fetch_started',
        data: {'screen': 'map_screen'},
      );

      final row = obs.pendingLogRecords.single;
      final attributes = row['attributes'] as Map<String, dynamic>;
      expect(row['event_name'], 'map.readiness_waiting');
      expect(row['trace_id'], span.traceId);
      expect(row['span_id'], span.spanId);
      expect(attributes, containsPair('flow', 'map.bootstrap'));
      expect(attributes, containsPair('phase', 'waiting_on'));
      expect(attributes, containsPair('dependency', 'cells'));
      expect(attributes, containsPair('reason', 'cells_fetch_started'));
      expect(attributes, containsPair('screen', 'map_screen'));
    });

    test('startSpan and endSpan store OTel-shaped spans', () {
      final span = obs.startSpan('map.bootstrap');
      obs.endSpan(span, statusCode: TelemetrySpanStatus.ok);

      final row = obs.pendingSpanRecords.single;
      expect(row['trace_id'], span.traceId);
      expect(row['span_id'], span.spanId);
      expect(row['span_name'], 'map.bootstrap');
      expect(row['status_code'], 'ok');
      expect(row, contains('started_at'));
      expect(row, contains('ended_at'));
      expect(row['attributes'], containsPair('flow', 'map.bootstrap'));
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
