import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CellRepositoryFailure', () {
    test('exposes only safe failure categories', () {
      const failures = [
        CellRepositoryFailure.unavailable(),
        CellRepositoryFailure.malformedPayload(),
      ];

      expect(
        failures.map((failure) => failure.kind),
        [
          CellRepositoryFailureKind.unavailable,
          CellRepositoryFailureKind.malformedPayload,
        ],
      );
      expect(
        failures.map((failure) => failure.toString()),
        [
          'Cell request failed (unavailable).',
          'Cell request failed (malformedPayload).',
        ],
      );
    });
  });
}
