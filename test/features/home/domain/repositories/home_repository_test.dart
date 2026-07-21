import 'package:earth_nova/features/home/domain/repositories/home_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeFailure', () {
    test('exposes stable safe failure kinds and messages', () {
      const failures = [
        HomeFailure.ownerMismatch(),
        HomeFailure.malformedPayload(),
        HomeFailure.unavailable(),
      ];

      expect(
        failures.map((failure) => failure.kind),
        [
          HomeFailureKind.ownerMismatch,
          HomeFailureKind.malformedPayload,
          HomeFailureKind.unavailable,
        ],
      );
      expect(
        failures.map((failure) => failure.toString()),
        [
          'Home request failed (ownerMismatch).',
          'Home request failed (malformedPayload).',
          'Home request failed (unavailable).',
        ],
      );
    });
  });
}
