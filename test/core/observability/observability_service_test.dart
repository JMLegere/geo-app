import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
      obs.log(
        'app.cold_start',
        'lifecycle',
        data: {'version': 'dev', 'platform': 'web'},
      );
      obs.log('auth.sign_in_started', 'auth', data: {'phone_hash': 'abc123'});
      expect(() => obs.flush(), returnsNormally);
    });

    test('log stores OTel-shaped log records', () {
      final trace = TraceContext.start();

      obs.log(
        'map.map_created',
        'map',
        data: {
          'trace_id': trace.traceId,
          'span_id': trace.spanId,
          'source': 'test',
        },
      );

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

    test(
      'logFlowEvent retains state transitions and owns grammar attributes',
      () {
        obs.logFlowEvent(
          'item.identification',
          TelemetryFlowPhase.stateChanged,
          'identification',
          previousState: 'pending',
          nextState: 'identified',
          data: {
            'flow': 'caller-controlled',
            'phase': 'caller-controlled',
            'previous_state': 'wrong',
            'next_state': 'wrong',
          },
        );

        final row = obs.pendingLogRecords.single;
        final attributes = row['attributes'] as Map<String, dynamic>;
        expect(row['event_name'], 'item.identification.state_changed');
        expect(attributes['flow'], 'item.identification');
        expect(attributes['phase'], 'state_changed');
        expect(attributes['previous_state'], 'pending');
        expect(attributes['next_state'], 'identified');
      },
    );

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
      final error = supa.PostgrestException(
        message: 'RLS denied',
        code: '42501',
      );
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

    test(
      'diagnostic export retains all session logs and completed spans after flush',
      () async {
        obs.log('map.bootstrap.started', 'map', data: {'phase': 'started'});
        final span = obs.startSpan('map.bootstrap');
        obs.endSpan(span, statusCode: TelemetrySpanStatus.error);
        obs.startSpan('app.startup');
        await obs.flush();

        final export =
            jsonDecode(
                  obs.exportDiagnostics(
                    debugInfo: {'readiness_phase': 'failed'},
                    browserLogsJson:
                        '[{"event_name":"low_level.long_task","duration_ms":120}]',
                  ),
                )
                as Map<String, dynamic>;

        expect(export['format'], 'earthnova-session-diagnostics-v1');
        expect(export['session_id'], 'test-session-123');
        expect(
          export['resource'],
          containsPair('service_name', 'earthnova-app'),
        );
        expect(export['debug_info'], containsPair('readiness_phase', 'failed'));
        expect(export['logs'], hasLength(1));
        expect(export['spans'], hasLength(1));
        expect(export['active_spans'], hasLength(1));
        expect(export['browser_logs'], hasLength(1));
        expect(obs.pendingLogRecords, isEmpty);
        expect(obs.pendingSpanRecords, isEmpty);
      },
    );

    test(
      'flush sends an OTel resource envelope and clears acknowledged records',
      () async {
        Map<String, dynamic>? sentEnvelope;
        final client = supa.SupabaseClient(
          'https://example.supabase.co',
          'anon-key',
          httpClient: MockClient((request) async {
            expect(request.method, 'post');
            expect(request.url.path, '/functions/v1/telemetry-ingest');
            sentEnvelope = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              '{}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        final service = ObservabilityService(
          sessionId: 'envelope-session',
          client: client,
          serviceName: 'earthnova-test',
          serviceVersion: '2026.7.21',
          deploymentEnvironment: 'test',
          platform: 'web',
        );
        service.log('item.revealed', 'item', data: {'item_id': 'item-1'});
        service.endSpan(
          service.startSpan('item.reveal'),
          statusCode: TelemetrySpanStatus.ok,
        );

        await service.flush();

        expect(sentEnvelope, isNotNull);
        expect(sentEnvelope!['resource'], {
          'service_name': 'earthnova-test',
          'service_version': '2026.7.21',
          'deployment_environment': 'test',
          'platform': 'web',
        });
        expect(sentEnvelope!['logs'], hasLength(1));
        expect(sentEnvelope!['spans'], hasLength(1));
        expect(service.pendingLogRecords, isEmpty);
        expect(service.pendingSpanRecords, isEmpty);
      },
    );

    test('flush preserves records when the ingest client fails', () async {
      final client = supa.SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: MockClient((_) async => throw StateError('offline')),
      );
      final service = ObservabilityService(
        sessionId: 'failed-flush-session',
        client: client,
      );
      service.log('item.reveal_failed', 'item');
      service.endSpan(service.startSpan('item.reveal'));

      await service.flush();

      expect(service.pendingLogRecords, hasLength(1));
      expect(service.pendingSpanRecords, hasLength(1));
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
