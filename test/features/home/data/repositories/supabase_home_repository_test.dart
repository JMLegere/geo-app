import 'package:earth_nova/features/home/data/repositories/supabase_home_repository.dart';
import 'package:earth_nova/features/home/domain/repositories/home_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _playerId = '11111111-1111-4111-8111-111111111111';

void main() {
  test('emits terminal Home RPC telemetry with safe errors', () async {
    final events = <Map<String, Object?>>[];
    final success = SupabaseHomeRepository(
      rpc: (_, {params}) async => {
        'id': '22222222-2222-4222-8222-222222222222',
        'user_id': _playerId,
        'created_at': '2026-07-20T12:00:00Z',
      },
      logEvent: (event, category, {data}) =>
          events.add({'event': event, 'category': category, 'data': data}),
    );

    await success.readHome(_playerId, traceId: 'home-trace');
    expect(events.map((event) => event['event']), [
      'db.rpc_started',
      'db.rpc_completed',
    ]);
    expect((events.last['data'] as Map)['operation'], 'get_v3_home');
    expect((events.last['data'] as Map)['duration_ms'], isA<int>());

    final failure = SupabaseHomeRepository(
      rpc: (_, {params}) async => throw StateError('database password'),
      logEvent: (event, category, {data}) =>
          events.add({'event': event, 'category': category, 'data': data}),
    );
    await expectLater(
      failure.readHome(_playerId, traceId: 'home-failure-trace'),
      throwsA(isA<HomeFailure>()),
    );
    expect(events.last['event'], 'db.rpc_failed');
    expect((events.last['data'] as Map)['error_message'], 'unavailable');
  });
  test('preserves owner mismatch while logging a terminal safe failure',
      () async {
    final events = <Map<String, Object?>>[];
    final repository = SupabaseHomeRepository(
      rpc: (_, {params}) async => {
        'id': '22222222-2222-4222-8222-222222222222',
        'user_id': '33333333-3333-4333-8333-333333333333',
        'created_at': '2026-07-20T12:00:00Z',
      },
      logEvent: (event, category, {data}) =>
          events.add({'event': event, 'category': category, 'data': data}),
    );

    await expectLater(
      repository.readHome(_playerId, traceId: 'home-owner-trace'),
      throwsA(isA<HomeFailure>().having(
        (failure) => failure.kind,
        'kind',
        HomeFailureKind.ownerMismatch,
      )),
    );

    expect(events.map((event) => event['event']),
        ['db.rpc_started', 'db.rpc_failed']);
    expect((events.last['data'] as Map)['error_message'], 'ownerMismatch');
  });
}
