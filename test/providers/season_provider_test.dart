import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/models/season.dart';
import 'package:earth_nova/providers/season_provider.dart';

void main() {
  group('seasonProvider', () {
    test('returns a Season value', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final season = container.read(seasonProvider);
      expect(season, isA<Season>());
    });

    test('matches Season.fromDate for current date', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final season = container.read(seasonProvider);
      final expected = Season.fromDate(DateTime.now());
      expect(season, expected);
    });
  });
}
