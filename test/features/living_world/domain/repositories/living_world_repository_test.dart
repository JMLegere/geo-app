import 'package:earth_nova/features/living_world/domain/repositories/living_world_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LivingWorldFailure', () {
    test('exposes every safe repository failure kind', () {
      const failures = [
        LivingWorldFailure.unknownVenue(),
        LivingWorldFailure.venueNotKnown(),
        LivingWorldFailure.cellVisitNotOwned(),
        LivingWorldFailure.cellVisitAnchorMismatch(),
        LivingWorldFailure.versionMismatch(),
        LivingWorldFailure.unavailable(),
        LivingWorldFailure.malformedPayload(),
      ];

      expect(
        failures.map((failure) => failure.kind),
        [
          LivingWorldFailureKind.unknownVenue,
          LivingWorldFailureKind.venueNotKnown,
          LivingWorldFailureKind.cellVisitNotOwned,
          LivingWorldFailureKind.cellVisitAnchorMismatch,
          LivingWorldFailureKind.versionMismatch,
          LivingWorldFailureKind.unavailable,
          LivingWorldFailureKind.malformedPayload,
        ],
      );
      expect(
        failures.map((failure) => failure.toString()),
        [
          'Living World request failed (unknownVenue).',
          'Living World request failed (venueNotKnown).',
          'Living World request failed (cellVisitNotOwned).',
          'Living World request failed (cellVisitAnchorMismatch).',
          'Living World request failed (versionMismatch).',
          'Living World request failed (unavailable).',
          'Living World request failed (malformedPayload).',
        ],
      );
    });
  });
}
