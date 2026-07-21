import 'package:earth_nova/features/home/data/dtos/home_dto.dart';
import 'package:earth_nova/features/home/domain/repositories/home_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../home_test_data.dart';

void main() {
  group('HomeDto', () {
    test('parses exactly the frozen get_v3_home shape', () {
      final home =
          HomeDto.fromJson(homePayload(), playerId: playerId).toDomain();

      expect(home.id, homeId);
      expect(home.playerId, playerId);
      expect(home.createdAt, DateTime.utc(2026, 7, 21));
    });

    test('rejects owner mismatch', () {
      final payload = homePayload()..['user_id'] = otherPlayerId;

      expect(
        () => HomeDto.fromJson(payload, playerId: playerId),
        throwsA(isA<HomeFailure>().having(
          (failure) => failure.kind,
          'kind',
          HomeFailureKind.ownerMismatch,
        )),
      );
    });

    test('rejects malformed, missing, and extra wire fields', () {
      final extra = homePayload()..['untrusted'] = true;
      final missing = homePayload()..remove('created_at');
      final malformedId = homePayload()..['id'] = 'not-a-uuid';
      final malformedTimestamp = homePayload()..['created_at'] = '2026-07-21';

      for (final payload in [extra, missing, malformedId, malformedTimestamp]) {
        expect(
          () => HomeDto.fromJson(payload, playerId: playerId),
          throwsA(isA<HomeFailure>().having(
            (failure) => failure.kind,
            'kind',
            HomeFailureKind.malformedPayload,
          )),
        );
      }
    });

    test('rejects an empty or non-object response and invalid local owner', () {
      for (final response in <Object?>[
        <String, Object?>{},
        <Object?>[],
        'not a response object',
      ]) {
        expect(
          () => HomeDto.fromJson(response, playerId: playerId),
          throwsA(isA<HomeFailure>().having(
            (failure) => failure.kind,
            'kind',
            HomeFailureKind.malformedPayload,
          )),
        );
      }
      expect(
        () => HomeDto.validatePlayerId('not-a-player-id'),
        throwsA(isA<HomeFailure>().having(
          (failure) => failure.kind,
          'kind',
          HomeFailureKind.malformedPayload,
        )),
      );
    });
  });
}
