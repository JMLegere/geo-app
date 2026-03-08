import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/season.dart';
import 'package:earth_nova/core/state/season_provider.dart';

void main() {
  group('SeasonNotifier', () {
    test('starts with the current real-world season', () {
      final container = ProviderContainer();
      final state = container.read(seasonProvider);
      final expected = Season.fromDate(DateTime.now());

      expect(state, equals(expected));
    });

    test('setSeason changes season', () {
      final container = ProviderContainer();
      final notifier = container.read(seasonProvider.notifier);

      notifier.setSeason(Season.winter);

      final state = container.read(seasonProvider);
      expect(state, equals(Season.winter));
    });

    test('setSeason can change back to summer', () {
      final container = ProviderContainer();
      final notifier = container.read(seasonProvider.notifier);

      notifier.setSeason(Season.winter);
      notifier.setSeason(Season.summer);

      final state = container.read(seasonProvider);
      expect(state, equals(Season.summer));
    });

    test('toggleSeason flips to opposite and back', () {
      final container = ProviderContainer();
      final notifier = container.read(seasonProvider.notifier);
      final initial = container.read(seasonProvider);

      notifier.toggleSeason();
      expect(container.read(seasonProvider), equals(initial.opposite));

      notifier.toggleSeason();
      expect(container.read(seasonProvider), equals(initial));
    });

    test('toggleSeason works multiple times', () {
      final container = ProviderContainer();
      final notifier = container.read(seasonProvider.notifier);
      final initial = container.read(seasonProvider);

      for (int i = 0; i < 5; i++) {
        notifier.toggleSeason();
      }

      // 5 toggles from any initial = opposite
      final state = container.read(seasonProvider);
      expect(state, equals(initial.opposite));
    });
  });
}
