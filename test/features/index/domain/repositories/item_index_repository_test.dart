import 'package:earth_nova/features/index/domain/repositories/item_index_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ItemIndexFailure', () {
    test('exposes stable safe failure kinds and messages', () {
      const failures = [
        ItemIndexFailure.unavailable(),
        ItemIndexFailure.malformedPayload(),
      ];

      expect(
        failures.map((failure) => failure.kind),
        [
          ItemIndexFailureKind.unavailable,
          ItemIndexFailureKind.malformedPayload,
        ],
      );
      expect(
        failures.map((failure) => failure.toString()),
        [
          'Item Index request failed (unavailable).',
          'Item Index request failed (malformedPayload).',
        ],
      );
    });
  });
}
