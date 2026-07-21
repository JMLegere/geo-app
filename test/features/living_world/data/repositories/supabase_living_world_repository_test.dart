import 'package:earth_nova/features/living_world/data/repositories/supabase_living_world_repository.dart';
import 'package:earth_nova/features/living_world/domain/repositories/living_world_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../living_world_test_data.dart';

void main() {
  group('SupabaseLivingWorldRepository', () {
    test('uses only frozen RPC names and exact command params without user id',
        () async {
      final calls = <({String name, Map<String, Object?>? params})>[];
      final events = <Map<String, Object?>>[];
      final repository = SupabaseLivingWorldRepository(
        rpc: (name, {params}) async {
          calls.add((name: name, params: params));
          return switch (name) {
            'get_v3_town' => town(),
            'record_v3_venue_visit' => recordResponse(),
            _ => throw StateError('unexpected RPC'),
          };
        },
        logEvent: (event, category, {data}) =>
            events.add({'event': event, 'category': category, 'data': data}),
      );

      await repository.readTown(playerId, traceId: 'read-trace');
      final result =
          await repository.recordVenueVisit(command(), traceId: 'visit-trace');

      expect(calls, hasLength(2));
      expect(calls.first.name, 'get_v3_town');
      expect(calls.first.params, isNull);
      expect(calls.last.name, 'record_v3_venue_visit');
      expect(calls.last.params, {
        'p_cell_visit_id': cellVisitId,
        'p_venue_id': 'venue:harbor',
        'p_expected_venue_version_id': venueVersionId,
      });
      expect(calls.last.params!.containsKey('user_id'), isFalse);
      expect(result.town.playerId, playerId);
      expect(events.map((event) => event['event']), [
        'db.rpc_started',
        'db.rpc_completed',
        'db.rpc_started',
        'db.rpc_completed',
      ]);
      expect(
          (events.last['data'] as Map)['operation'], 'record_v3_venue_visit');
      expect((events.last['data'] as Map)['duration_ms'], isA<int>());
    });

    test('preserves safe malformed failures and hides transport details',
        () async {
      final malformed = SupabaseLivingWorldRepository(
          rpc: (_, {params}) async => {'venues': 'bad'});
      await expectLater(
        malformed.readTown(playerId, traceId: 'trace'),
        throwsA(isA<LivingWorldFailure>().having(
          (failure) => failure.kind,
          'kind',
          LivingWorldFailureKind.malformedPayload,
        )),
      );

      final events = <Map<String, Object?>>[];
      final unavailable = SupabaseLivingWorldRepository(
        rpc: (_, {params}) =>
            Future<Object?>.error(StateError('database password: never leak')),
        logEvent: (event, category, {data}) =>
            events.add({'event': event, 'category': category, 'data': data}),
      );
      await expectLater(
        unavailable.readTown(playerId, traceId: 'trace'),
        throwsA(isA<LivingWorldFailure>().having(
          (failure) => failure.toString(),
          'safe message',
          isNot(contains('database password')),
        )),
      );
      expect(events.last['event'], 'db.rpc_failed');
      expect((events.last['data'] as Map)['error_message'], 'unavailable');
    });

    test('maps record transport failures to safe terminal telemetry', () async {
      final events = <Map<String, Object?>>[];
      final repository = SupabaseLivingWorldRepository(
        rpc: (_, {params}) =>
            Future<Object?>.error(StateError('record secret must not leak')),
        logEvent: (event, category, {data}) =>
            events.add({'event': event, 'category': category, 'data': data}),
      );

      await expectLater(
        repository.recordVenueVisit(command(), traceId: 'record-failure-trace'),
        throwsA(isA<LivingWorldFailure>().having(
          (failure) => failure.kind,
          'kind',
          LivingWorldFailureKind.unavailable,
        )),
      );

      expect(events.map((event) => event['event']),
          ['db.rpc_started', 'db.rpc_failed']);
      expect(
          (events.last['data'] as Map)['operation'], 'record_v3_venue_visit');
      expect((events.last['data'] as Map)['error_message'], 'unavailable');
      expect(events.join(), isNot(contains('record secret')));
    });
  });
}
