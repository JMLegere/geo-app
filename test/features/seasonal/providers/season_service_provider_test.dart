import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/seasonal/providers/season_service_provider.dart';
import 'package:earth_nova/features/seasonal/services/season_service.dart';

void main() {
  group('seasonServiceProvider', () {
    test('returns a SeasonService instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(seasonServiceProvider);

      expect(service, isA<SeasonService>());
    });

    test('returns the same instance on repeated reads (cached)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final first = container.read(seasonServiceProvider);
      final second = container.read(seasonServiceProvider);

      expect(identical(first, second), isTrue);
    });
  });
}
