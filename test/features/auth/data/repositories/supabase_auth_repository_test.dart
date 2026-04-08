import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseAuthRepository trace logging', () {
    test('logs query started/completed with trace_id', () async {
      final events = <Map<String, dynamic>>[];

      final repository = SupabaseAuthRepository(
        client: null,
        signInAction: (_, __) async => UserProfile(
          id: 'u1',
          phone: '1234567890',
          displayName: 'Explorer',
          createdAt: DateTime(2026),
        ),
        logEvent: (event, category, {data}) {
          events
              .add({'event': event, 'category': category, 'data': data ?? {}});
        },
      );

      final user = await repository.signInWithEmail(
        '1234567890@earthnova.app',
        'secret',
        traceId: 'trace-auth',
      );

      expect(user.id, 'u1');
      expect(events, hasLength(2));
      expect(events[0]['event'], 'db.query_started');
      expect(events[0]['data']['trace_id'], 'trace-auth');
      expect(events[1]['event'], 'db.query_completed');
      expect(events[1]['data']['trace_id'], 'trace-auth');
      expect(events[1]['data']['row_count'], 1);
      expect(events[1]['data']['duration_ms'], isA<int>());
    });

    test('logs query failed with trace_id', () async {
      final events = <Map<String, dynamic>>[];

      final repository = SupabaseAuthRepository(
        client: null,
        signInAction: (_, __) async => throw const AuthException('bad creds'),
        logEvent: (event, category, {data}) {
          events
              .add({'event': event, 'category': category, 'data': data ?? {}});
        },
      );

      await expectLater(
        () => repository.signInWithEmail(
          '1234567890@earthnova.app',
          'secret',
          traceId: 'trace-auth-fail',
        ),
        throwsA(isA<AuthException>()),
      );

      expect(events, hasLength(2));
      expect(events[0]['event'], 'db.query_started');
      expect(events[1]['event'], 'db.query_failed');
      expect(events[1]['data']['trace_id'], 'trace-auth-fail');
    });
  });
}
