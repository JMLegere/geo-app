import 'package:earth_nova/features/map/domain/repositories/hierarchy_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HierarchyRepositoryFailure', () {
    test('exposes only safe failure categories', () {
      const failures = [
        HierarchyRepositoryFailure.unavailable(),
        HierarchyRepositoryFailure.malformedPayload(),
      ];

      expect(
        failures.map((failure) => failure.kind),
        [
          HierarchyRepositoryFailureKind.unavailable,
          HierarchyRepositoryFailureKind.malformedPayload,
        ],
      );
      expect(
        failures.map((failure) => failure.toString()),
        [
          'Hierarchy request failed (unavailable).',
          'Hierarchy request failed (malformedPayload).',
        ],
      );
    });
  });
}
