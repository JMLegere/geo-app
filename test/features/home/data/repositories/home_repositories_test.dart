import 'package:earth_nova/features/home/data/repositories/mock_home_repository.dart';
import 'package:earth_nova/features/home/data/repositories/supabase_home_repository.dart';
import 'package:earth_nova/features/home/domain/entities/home.dart';
import 'package:earth_nova/features/home/domain/repositories/home_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../home_test_data.dart';

void main() {
  group('SupabaseHomeRepository', () {
    test('calls frozen get_v3_home with no params or client-supplied user id',
        () async {
      final calls = <({String name, Map<String, Object?>? params})>[];
      final events = <Map<String, Object?>>[];
      final repository = SupabaseHomeRepository(
        rpc: (name, {params}) async {
          calls.add((name: name, params: params));
          return homePayload();
        },
        logEvent: (event, category, {data}) => events.add({
          'event': event,
          'category': category,
          'data': data,
        }),
      );

      final home = await repository.readHome(playerId, traceId: 'home-read');

      expect(home.playerId, playerId);
      expect(calls, hasLength(1));
      expect(calls.single.name, 'get_v3_home');
      expect(calls.single.params, isNull);
      expect(
        events.map((event) => (event['data'] as Map)['trace_id']),
        ['home-read', 'home-read'],
      );
    });

    test('preserves safe parse failures and hides transport details', () async {
      final malformed =
          SupabaseHomeRepository(rpc: (_, {params}) async => {'id': homeId});
      await expectLater(
        malformed.readHome(playerId, traceId: 'home-read'),
        throwsA(isA<HomeFailure>().having(
          (failure) => failure.kind,
          'kind',
          HomeFailureKind.malformedPayload,
        )),
      );

      final unavailable = SupabaseHomeRepository(
        rpc: (_, {params}) =>
            Future<Object?>.error(StateError('database password: never leak')),
      );
      await expectLater(
        unavailable.readHome(playerId, traceId: 'home-read'),
        throwsA(isA<HomeFailure>().having(
          (failure) => failure.toString(),
          'safe message',
          isNot(contains('database password')),
        )),
      );
    });
  });

  group('MockHomeRepository', () {
    test('returns only an explicitly supplied matching Home', () async {
      final home = Home(
        id: homeId,
        playerId: playerId,
        createdAt: DateTime.parse(createdAt),
      );
      final repository = MockHomeRepository(home: home);

      expect(await repository.readHome(playerId, traceId: 'home-read'),
          same(home));
      await expectLater(
        repository.readHome(otherPlayerId, traceId: 'home-read'),
        throwsA(isA<HomeFailure>().having(
          (failure) => failure.kind,
          'kind',
          HomeFailureKind.unavailable,
        )),
      );
      expect(repository.readCount, 2);
    });
  });
}
